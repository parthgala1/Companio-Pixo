import Foundation
import Combine

// MARK: - SpeechViewModel

/// Manages the full speech pipeline: listening → transcription → IntentRouter → play mode / LLM → TTS.
final class SpeechViewModel: ObservableObject {

    // MARK: - Published
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var responseText = ""
    @Published var errorMessage: String?
    @Published var isThinking = false

    /// Reference to companion face VM — injected after init via `configure(companionVM:)`.
    weak var companionVM: CompanionViewModel?

    /// Guards against double-routing the same utterance.
    private var hasRoutedCurrentInput = false

    // MARK: - Dependencies
    private let speechService: SpeechService
    private let llmService: LLMService
    private let elevenLabsService: ElevenLabsService
    private let emotionEngine: EmotionEngine
    private let memoryService: MemoryService
    private let soundService: SoundService
    let playModeVM: PlayModeViewModel

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(speechService: SpeechService = .shared,
         llmService: LLMService = .shared,
         elevenLabsService: ElevenLabsService = .shared,
         emotionEngine: EmotionEngine = .shared,
         memoryService: MemoryService = .shared,
         soundService: SoundService = .shared,
         playModeVM: PlayModeViewModel = PlayModeViewModel()) {
        self.speechService = speechService
        self.llmService = llmService
        self.elevenLabsService = elevenLabsService
        self.emotionEngine = emotionEngine
        self.memoryService = memoryService
        self.soundService = soundService
        self.playModeVM = playModeVM
        bindToSpeechService()
        bindToPlayMode()
    }

    // MARK: - Bindings

    private func bindToSpeechService() {
        speechService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSpeechEvent(event)
            }
            .store(in: &cancellables)

        speechService.$isSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)
    }

    private func bindToPlayMode() {
        playModeVM.$responseText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                if !text.isEmpty { self?.responseText = text }
            }
            .store(in: &cancellables)
    }

    /// Injects the CompanionViewModel reference after creation.
    /// Called from CompanioApp.init after both VMs exist.
    func configure(companionVM: CompanionViewModel) {
        self.companionVM = companionVM
        playModeVM.setCompanionVM(companionVM)

        // Track ElevenLabs speaking state so UI knows about voice output
        // and resume STT when playback finishes
        elevenLabsService.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                guard let self else { return }
                if speaking {
                    self.isSpeaking = true
                } else if self.speechService.isPaused {
                    // ElevenLabs finished — resume always-on listening
                    self.isSpeaking = false
                    self.speechService.resumeListening()
                }
            }
            .store(in: &cancellables)

        // Also resume STT when system TTS finishes (fallback path)
        speechService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                if case .didFinishSpeaking = event, self.speechService.isPaused {
                    self.speechService.resumeListening()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Speech Event Handling

    private func handleSpeechEvent(_ event: SpeechEvent) {
        switch event {
        case .didStartListening:
            // Wake word detected — show listening state
            isListening = true
            hasRoutedCurrentInput = false
            responseText = ""
            errorMessage = nil
        case .didStopListening:
            isListening = false
        case .didTranscribe(let text, let isFinal):
            transcribedText = text
            if isFinal && !text.trimmingCharacters(in: .whitespaces).isEmpty && !hasRoutedCurrentInput {
                hasRoutedCurrentInput = true
                print("[Pixo] Final transcription: \(text)")
                routeInput(text)
            }
        case .didStartSpeaking:
            isSpeaking = true
        case .didFinishSpeaking:
            isSpeaking = false
        case .phoneme(let viseme, _):
            let openness = visemeToOpenness(viseme)
            NotificationCenter.default.post(
                name: .companioMouthOpenness,
                object: nil,
                userInfo: ["openness": openness]
            )
        case .error(let err):
            errorMessage = err.localizedDescription
            print("[Pixo] Speech error: \(err.localizedDescription)")
        }
    }

    // MARK: - Input Routing (via IntentRouter)

    private func routeInput(_ text: String) {
        emotionEngine.onInteraction()
        memoryService.addUserMessage(text)

        let command = IntentRouter.route(text)
        print("[Pixo] Routed to: \(command.displayName)")

        switch command {
        case .llm(let cleanedText):
            Task { await sendToLLM(cleanedText) }
        case .stop:
            stopListening()
            playModeVM.stopActiveMode()
        default:
            playModeVM.handle(command)
        }
    }

    // MARK: - LLM

    @MainActor
    private func sendToLLM(_ text: String) async {
        isThinking = true
        companionVM?.setThinking(true)
        print("[Pixo] Sending to LLM: \(text)")
        soundService.play(.thinking, emotionState: emotionEngine.state)

        let isSilent = UserDefaults.standard.bool(forKey: "pixo_silent_mode")

        do {
            let response = try await llmService.send(
                userMessage: text,
                emotionState: emotionEngine.state,
                memory: memoryService.currentMemory
            )

            print("[Pixo] LLM response: \(response)")
            responseText = response
            memoryService.addAssistantMessage(response)
            emotionEngine.onPositiveOutcome()

            let sentiment = simpleSentimentScore(response)
            emotionEngine.onSpeechSentiment(sentiment)

            // Speak response unless silent mode is on
            if !isSilent {
                // Pause STT so ElevenLabs audio engine can take the audio session
                speechService.pauseListening()
                elevenLabsService.speak(response, emotionState: emotionEngine.state)
            }

        } catch LLMError.missingAPIKey {
            let fallback = "I'd love to chat, but I need a Groq API key first!"
            print("[Pixo] No Groq API key")
            responseText = fallback
            if !isSilent {
                speechService.pauseListening()
                speechService.speak(fallback)
            }
        } catch {
            let msg = error.localizedDescription
            print("[Pixo] LLM error: \(msg)")
            errorMessage = msg
            responseText = "Pixo is thinking but something went wrong."
            emotionEngine.onNegativeOutcome()
            if !isSilent {
                speechService.pauseListening()
                speechService.speak("Sorry, I couldn't think of a response.")
            }
        }

        isThinking = false
        companionVM?.setThinking(false)
    }

    // MARK: - Controls

    /// Starts always-on listening for the "Hey Pixo" wake phrase.
    /// Call once on app launch; recognition restarts automatically.
    func startAlwaysOnListening() {
        print("[Pixo] Starting always-on wake word listening...")
        speechService.alwaysOnListening = true
        speechService.requestPermissions { [weak self] granted in
            if granted {
                self?.speechService.startListening()
            } else {
                self?.errorMessage = "Microphone permission required."
            }
        }
    }

    /// Legacy one-shot listening (no longer used by default).
    func startListening() {
        errorMessage = nil
        transcribedText = ""
        responseText = ""
        hasRoutedCurrentInput = false
        print("[Pixo] Start listening...")
        speechService.alwaysOnListening = false
        speechService.requestPermissions { [weak self] granted in
            if granted {
                self?.speechService.startListening()
            } else {
                self?.errorMessage = "Microphone permission required."
            }
        }
    }

    func stopListening() {
        speechService.stopListening()
    }

    func stopSpeaking() {
        speechService.stopSpeaking()
        elevenLabsService.stopSpeaking()
    }

    // MARK: - Helpers

    private func visemeToOpenness(_ viseme: Int) -> Double {
        let opennessMap: [Int: Double] = [
            0: 0.0, 1: 0.3, 2: 0.5, 3: 0.7, 4: 0.9,
            5: 0.8, 6: 0.6, 7: 0.4, 8: 0.2, 9: 0.1
        ]
        return opennessMap[viseme] ?? 0.3
    }

    private func simpleSentimentScore(_ text: String) -> Double {
        let positiveWords = ["great", "happy", "love", "wonderful", "amazing", "yes", "good", "awesome", "excited", "glad"]
        let negativeWords = ["bad", "sad", "hate", "terrible", "awful", "no", "wrong", "sorry", "unfortunately", "fail"]
        let lower = text.lowercased()
        let posCount = positiveWords.filter { lower.contains($0) }.count
        let negCount = negativeWords.filter { lower.contains($0) }.count
        let total = posCount + negCount
        guard total > 0 else { return 0 }
        return Double(posCount - negCount) / Double(total)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let companioMouthOpenness = Notification.Name("companio.mouthOpenness")
}
