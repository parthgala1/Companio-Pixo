import Foundation
import Combine

// MARK: - PlayModeViewModel

/// Orchestrates all play mode lifecycles.
/// Receives FeatureCommands from SpeechViewModel and manages mode state.
/// Play modes are temporary overlays — EmotionEngine remains global.
final class PlayModeViewModel: ObservableObject {

    // MARK: - Published
    @Published private(set) var activeMode: FeatureCommand?
    @Published private(set) var moodGuessState: MoodGuessState = .idle
    @Published private(set) var staringContestResult: StaringContestResult?
    @Published private(set) var responseText: String = ""

    // MARK: - Dependencies
    private let emotionEngine: EmotionEngine
    private let llmService: LLMService
    private let elevenLabsService: ElevenLabsService
    private let speechService: SpeechService
    private let memoryService: MemoryService
    private let copyModeManager: CopyModeManager
    private let danceController: DanceAnimationController
    private let blinkDetector: BlinkDetectionManager
    private let faceDetectionService: FaceDetectionService
    private weak var companionVM: CompanionViewModel?

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(emotionEngine: EmotionEngine = .shared,
         llmService: LLMService = .shared,
         elevenLabsService: ElevenLabsService = .shared,
         speechService: SpeechService = .shared,
         memoryService: MemoryService = .shared,
         copyModeManager: CopyModeManager = .shared,
         danceController: DanceAnimationController = .shared,
         blinkDetector: BlinkDetectionManager = .shared,
         faceDetectionService: FaceDetectionService = .shared,
         companionVM: CompanionViewModel? = nil) {
        self.emotionEngine = emotionEngine
        self.llmService = llmService
        self.elevenLabsService = elevenLabsService
        self.speechService = speechService
        self.memoryService = memoryService
        self.copyModeManager = copyModeManager
        self.danceController = danceController
        self.blinkDetector = blinkDetector
        self.faceDetectionService = faceDetectionService
        self.companionVM = companionVM
    }

    /// Injects the CompanionViewModel reference after creation.
    func setCompanionVM(_ vm: CompanionViewModel) {
        self.companionVM = vm
    }

    // MARK: - Command Handling

    /// Main entry point — called by SpeechViewModel after IntentRouter classification.
    func handle(_ command: FeatureCommand) {
        switch command {
        case .stop:
            stopActiveMode()

        case .copyMe:
            activateMode(.copyMe)
            copyModeManager.start()
            companionVM?.showHands(mood: .copy)
            companionVM?.showEmote(.happy, duration: nil)  // persists while in mode

        case .dance:
            activateMode(.dance)
            danceController.start()
            companionVM?.showHands(mood: .dance)
            companionVM?.showEmote(.singing, duration: nil)  // persists while dancing

        case .guessMood:
            activateMode(.guessMood)
            startMoodGuessGame()
            companionVM?.showEmote(.confused, duration: 2.0)

        case .story:
            activateMode(.story)
            Task { await runStoryMode() }

        case .staringContest:
            activateMode(.staringContest)
            startStaringContest()
            companionVM?.showEmote(.shocked, duration: nil)  // wide eyes for staring

        case .compliment:
            activateMode(.compliment)
            Task { await runComplimentMode() }
            companionVM?.showEmote(.love, duration: 3.0)

        case .roast:
            activateMode(.roast)
            Task { await runRoastMode() }
            companionVM?.showEmote(.laughing, duration: 3.0)

        case .silentCompanion:
            activateMode(.silentCompanion)
            emotionEngine.onPlayModeEvent(.silentCompanion)
            companionVM?.showEmote(.sleeping, duration: nil)  // persists while silent

        case .llm:
            break  // Handled by SpeechViewModel directly
        }
    }

    /// Called when user says "yes" in mood guess confirmation.
    func confirmMoodGuess(correct: Bool) {
        guard case .presenting(let prediction) = moodGuessState else { return }
        moodGuessState = .confirmed(correct: correct)

        if correct {
            emotionEngine.onPlayModeEvent(.moodGuessCorrect)
            let response = MoodClassifier.correctResponse(for: prediction)
            speak(response)
            companionVM?.showEmote(.joyful, duration: 3.0)
        } else {
            emotionEngine.onPlayModeEvent(.moodGuessIncorrect)
            let response = MoodClassifier.incorrectResponse()
            speak(response)
            companionVM?.showEmote(.sad, duration: 3.0)
        }

        // Return to idle after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.moodGuessState = .idle
            self?.stopActiveMode()
        }
    }

    // MARK: - Private Mode Implementations

    private func activateMode(_ mode: FeatureCommand) {
        stopActiveMode()
        activeMode = mode
    }

    func stopActiveMode() {
        switch activeMode {
        case .copyMe:         copyModeManager.stop()
        case .dance:          danceController.stop()
        case .staringContest: blinkDetector.stopMonitoring()
        default:              break
        }
        companionVM?.hideHands()
        companionVM?.clearEmote()  // Clear any mode-persistent emote
        activeMode = nil
        moodGuessState = .idle
        staringContestResult = nil
        elevenLabsService.stopSpeaking()
    }

    // MARK: - Mood Guess

    private func startMoodGuessGame() {
        moodGuessState = .analyzing
        speak("Let me read your face for a moment...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            let sentiment = self.emotionEngine.state.valence
            let arousal = self.emotionEngine.state.arousal
            let prediction = MoodClassifier.classify(
                smileProbability: nil,
                sentimentScore: sentiment,
                arousal: arousal
            )
            self.moodGuessState = .presenting(prediction: prediction)
            let question = MoodClassifier.confirmationQuestion(for: prediction)
            self.speak(question)
        }
    }

    // MARK: - Story Mode

    @MainActor
    private func runStoryMode() async {
        emotionEngine.onPlayModeEvent(.storyMode)
        speak("Hmm, let me think of something...")

        let prompt = "Tell me a short, imaginative story in exactly 3 sentences. Make it warm and whimsical."
        do {
            let story = try await llmService.send(
                userMessage: prompt,
                emotionState: emotionEngine.state,
                memory: memoryService.currentMemory
            )
            responseText = story
            if !UserDefaults.standard.bool(forKey: "pixo_silent_mode") {
                elevenLabsService.speak(story, emotionState: emotionEngine.state)
            }
        } catch {
            speak("I had a story in mind, but it slipped away. Maybe next time!")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.stopActiveMode()
        }
    }

    // MARK: - Compliment Mode

    @MainActor
    private func runComplimentMode() async {
        emotionEngine.onPlayModeEvent(.complimentGiven)

        let prompt = "Give me a genuine, warm compliment in exactly 2 sentences. Be specific and heartfelt."
        do {
            let compliment = try await llmService.send(
                userMessage: prompt,
                emotionState: emotionEngine.state,
                memory: memoryService.currentMemory
            )
            responseText = compliment
            if !UserDefaults.standard.bool(forKey: "pixo_silent_mode") {
                elevenLabsService.speak(compliment, emotionState: emotionEngine.state)
            }
        } catch {
            speak("You're doing amazing — I mean it!")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.stopActiveMode()
        }
    }

    // MARK: - Roast Mode

    @MainActor
    private func runRoastMode() async {
        emotionEngine.onPlayModeEvent(.roastMode)

        let prompt = """
        Give me a playful, safe roast in exactly 2 sentences. \
        Be witty and sarcastic but never mean-spirited or hurtful. \
        Keep it light and funny — like a friend teasing another friend.
        """
        do {
            let roast = try await llmService.send(
                userMessage: prompt,
                emotionState: emotionEngine.state,
                memory: memoryService.currentMemory
            )
            responseText = roast
            if !UserDefaults.standard.bool(forKey: "pixo_silent_mode") {
                elevenLabsService.speak(roast, emotionState: emotionEngine.state)
            }
        } catch {
            speak("I was going to roast you, but you're too cool for that!")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.stopActiveMode()
        }
    }

    // MARK: - Staring Contest

    private func startStaringContest() {
        staringContestResult = nil
        blinkDetector.startMonitoring()
        speak("Okay, don't blink! Starting now... 👁️")

        blinkDetector.userBlinkedPublisher
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.endStaringContest(pixoWon: true)
            }
            .store(in: &cancellables)

        blinkDetector.pixoBlinkedPublisher
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.endStaringContest(pixoWon: false)
            }
            .store(in: &cancellables)
    }

    private func endStaringContest(pixoWon: Bool) {
        blinkDetector.stopMonitoring()
        staringContestResult = pixoWon ? .pixoWon : .userWon

        if pixoWon {
            emotionEngine.onPlayModeEvent(.staringContestWin)
            companionVM?.showHands(mood: .celebrate)
            companionVM?.showEmote(.proud, duration: 4.0)
            speak("Ha! You blinked! I win!")
        } else {
            emotionEngine.onPlayModeEvent(.staringContestLose)
            companionVM?.showHands(mood: .embarrass)
            companionVM?.showEmote(.sad, duration: 4.0)
            speak("No way... I blinked first. You're good!")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.stopActiveMode()
        }
    }

    // MARK: - Speak Helper

    private func speak(_ text: String) {
        responseText = text
        let isSilent = UserDefaults.standard.bool(forKey: "pixo_silent_mode")
        guard !isSilent else { return }
        speechService.speak(text,
                            pitchMultiplier: Float(1.0 + emotionEngine.state.valence * 0.1),
                            rateMultiplier: Float(0.9 + emotionEngine.state.arousal * 0.1))
    }
}

// MARK: - StaringContestResult

enum StaringContestResult {
    case pixoWon
    case userWon
}
