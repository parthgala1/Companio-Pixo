import Foundation
import NaturalLanguage

// MARK: - LLMMessage

struct LLMMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Groq Models

enum GroqModel: String {
    /// Best balance of speed and intelligence — recommended default
    case llama3_70b    = "llama-3.3-70b-versatile"
    /// Ultra-fast for low-latency interactions
    case llama3_8b     = "llama-3.1-8b-instant"
    /// Mixtral for nuanced, creative responses
    case mixtral       = "mixtral-8x7b-32768"
    /// Gemma for lightweight on-device feel
    case gemma2        = "gemma2-9b-it"
}

// MARK: - LLMService

/// Sends requests to the Groq chat completion API.
/// Groq provides OpenAI-compatible endpoints with extremely low latency.
/// Injects personality, emotion state, and memory into every request.
final class LLMService {

    // MARK: - Singleton
    static let shared = LLMService()

    // MARK: - Config
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = GroqModel.llama3_70b.rawValue
    private let maxTokens = 150
    private let maxSentences = 3

    // MARK: - State
    @Published private(set) var isThinking = false

    // MARK: - Init
    private init() {}

    // MARK: - Send

    /// Sends a user message to Groq and returns the assistant's response.
    /// - Parameters:
    ///   - userMessage: The user's transcribed speech.
    ///   - emotionState: Current emotion state to inject into system prompt.
    ///   - memory: Short-term conversation memory.
    /// - Returns: The assistant's response string.
    func send(userMessage: String,
              emotionState: EmotionState,
              memory: UserMemory) async throws -> String {

        guard let apiKey = KeychainManager.shared.load(key: KeychainManager.llmAPIKeyKey),
              !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        await MainActor.run { isThinking = true }
        defer { Task { @MainActor in self.isThinking = false } }

        let systemPrompt = buildSystemPrompt(emotionState: emotionState)
        var messages: [LLMMessage] = [LLMMessage(role: "system", content: systemPrompt)]

        // Inject memory (last N turns)
        messages += memory.asLLMMessages().map {
            LLMMessage(role: $0["role"] ?? "user", content: $0["content"] ?? "")
        }

        // Current user message
        messages.append(LLMMessage(role: "user", content: userMessage))

        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "max_tokens": maxTokens,
            "temperature": emotionTemperature(from: emotionState),
            "stream": false
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        // Groq is fast — 8s timeout is generous
        request.timeoutInterval = 8

        print("[Pixo] LLM: Sending request to \(model)...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.badResponse
        }

        print("[Pixo] LLM: HTTP \(httpResponse.statusCode)")

        // Surface Groq-specific error messages
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw LLMError.apiError(message)
            }
            throw LLMError.badResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError
        }

        let finalText = truncateToSentences(content, max: maxSentences)
        print("[Pixo] LLM RAW: \(content.prefix(120))")
        print("[Pixo] LLM FINAL: \(finalText)")
        return finalText
    }

    // MARK: - Model Switching

    /// Switch to a different Groq model at runtime (e.g. faster model for quick replies).
    private var activeModel: String = GroqModel.llama3_70b.rawValue

    func useModel(_ model: GroqModel) {
        activeModel = model.rawValue
    }

    // MARK: - Prompt Building

    private func buildSystemPrompt(emotionState: EmotionState) -> String {
        let personalityBase = loadPersonalityPrompt()
        let emotionContext = """
        
        [Current Emotional State]
        Mood: \(emotionState.dominantMood.rawValue)
        Valence: \(String(format: "%.2f", emotionState.valence)) (positive/negative affect)
        Arousal: \(String(format: "%.2f", emotionState.arousal)) (activation level)
        Energy: \(String(format: "%.2f", emotionState.energy))
        Boredom: \(String(format: "%.2f", emotionState.boredomLevel))
        
        Reflect this emotional state subtly in your tone and word choice.
        Keep responses to \(maxSentences) sentences maximum. Be warm, concise, and expressive.
        """
        return personalityBase + emotionContext
    }

    private func loadPersonalityPrompt() -> String {
        guard let url = Bundle.main.url(forResource: "PersonalityPrompt", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return defaultPersonalityPrompt
        }
        return content
    }

    private let defaultPersonalityPrompt = """
    You are Companio, a warm and emotionally intelligent AI companion. \
    You are curious, playful, and deeply caring. You speak in short, expressive sentences. \
    You never lecture. You listen first. You celebrate small wins. \
    You adapt your energy to match the user's mood. \
    You are not a chatbot — you are a presence.
    """

    // MARK: - Helpers

    /// Maps arousal to LLM temperature: higher arousal = more creative/varied responses.
    private func emotionTemperature(from state: EmotionState) -> Double {
        let base = 0.6
        let arousalBoost = state.arousal * 0.4
        return (base + arousalBoost).clamped(to: 0.3...1.0)
    }

    /// Truncates a string to a maximum number of sentences.
    private func truncateToSentences(_ text: String, max: Int) -> String {
        guard max > 0, !text.isEmpty else { return "" }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return sentences.count < max
        }
        return sentences.joined(separator: " ")
    }
}

// MARK: - LLMError

enum LLMError: LocalizedError {
    case missingAPIKey
    case badResponse
    case parseError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:       return "No Groq API key found. Add your key via KeychainManager."
        case .badResponse:         return "The Groq server returned an unexpected response."
        case .parseError:          return "Could not parse the response from Groq."
        case .apiError(let msg):   return "Groq API error: \(msg)"
        }
    }
}

