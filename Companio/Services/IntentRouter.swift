import Foundation

// MARK: - IntentRouter

/// Routes transcribed speech to a FeatureCommand before falling back to LLM.
/// Strips "hey pixo" wake prefix before matching.
enum IntentRouter {

    // MARK: - Route

    /// Classify a transcribed string into a FeatureCommand.
    static func route(_ text: String) -> FeatureCommand {
        let cleaned = stripWakePhrase(from: text).lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Stop / cancel — highest priority
        if matches(cleaned, keywords: ["stop", "cancel", "quit", "enough", "be quiet", "stop listening"]) {
            return .stop
        }

        // Copy Me
        if matches(cleaned, keywords: ["copy me", "mimic me", "mirror me", "copy my face"]) {
            return .copyMe
        }

        // Dance
        if matches(cleaned, keywords: ["dance", "let's dance", "start dancing", "do a dance"]) {
            return .dance
        }

        // Guess My Mood
        if matches(cleaned, keywords: ["guess my mood", "what's my mood", "what mood am i", "how am i feeling"]) {
            return .guessMood
        }

        // Story
        if matches(cleaned, keywords: ["tell me a story", "tell a story", "short story", "story time", "tell me something"]) {
            return .story
        }

        // Staring Contest
        if matches(cleaned, keywords: ["staring contest", "stare contest", "don't blink", "staring game"]) {
            return .staringContest
        }

        // Compliment
        if matches(cleaned, keywords: ["compliment me", "say something nice", "tell me something nice", "make me feel good"]) {
            return .compliment
        }

        // Roast
        if matches(cleaned, keywords: ["roast me", "make fun of me", "tease me", "be mean"]) {
            return .roast
        }

        // Silent Companion
        if matches(cleaned, keywords: ["just stay with me", "stay with me", "silent mode", "just be here", "don't talk", "quiet mode"]) {
            return .silentCompanion
        }

        // Fallback → LLM with original (non-cleaned) text
        let llmText = stripWakePhrase(from: text).trimmingCharacters(in: .whitespacesAndNewlines)
        return .llm(llmText.isEmpty ? text : llmText)
    }

    // MARK: - Helpers

    /// Strips "hey pixo", "pixo", "ok pixo" prefixes.
    static func stripWakePhrase(from text: String) -> String {
        let lower = text.lowercased()
        let wakePhrases = ["hey pixo,", "hey pixo", "ok pixo,", "ok pixo", "pixo,", "pixo"]
        for phrase in wakePhrases {
            if lower.hasPrefix(phrase) {
                return String(text.dropFirst(phrase.count))
            }
        }
        return text
    }

    /// Returns true if the text contains any of the given keywords.
    private static func matches(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
