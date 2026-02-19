import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - SpeechEvent

enum SpeechEvent {
    case didStartListening
    case didStopListening
    case didTranscribe(text: String, isFinal: Bool)
    case didStartSpeaking
    case didFinishSpeaking
    case phoneme(viseme: Int, duration: TimeInterval)
    case error(Error)
}

// MARK: - SpeechMode

enum SpeechMode {
    case command       // Short commands, routed to system actions
    case conversational // Full LLM conversation
}

// MARK: - SpeechService

/// Manages the full speech pipeline: STT → intent routing → TTS → lip sync.
final class SpeechService: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = SpeechService()

    // MARK: - Publishers
    let eventPublisher = PassthroughSubject<SpeechEvent, Never>()

    @Published private(set) var isListening = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var transcribedText = ""

    // MARK: - Mode
    var mode: SpeechMode = .conversational

    /// When true, the service runs continuous recognition and only
    /// emits a final transcription when it detects the "Hey Pixo" wake
    /// phrase. When false (legacy), any tap starts a one-shot listen.
    var alwaysOnListening: Bool = true

    // MARK: - Private — STT
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // VAD: amplitude threshold for voice activity detection
    private let voiceAmplitudeThreshold: Float = 0.01
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0

    /// Tracks whether we detected the wake phrase in the current
    /// recognition session so we can pass the rest to the router.
    private var wakeDetected = false
    private var lastPartialText: String = ""

    // MARK: - Private — TTS
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Init
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord,
                                  mode: .default,
                                 options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
    }

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                completion(false)
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // MARK: - STT

    func startListening() {
        guard !isListening, !audioEngine.isRunning else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)

            // Voice Activity Detection
            let frameLength: Int = Int(buffer.frameLength)
            if let channelDataPointer = buffer.floatChannelData {
                let channel0: UnsafeMutablePointer<Float> = channelDataPointer[0]
                var sumSquares: Float = 0
                // Compute RMS without higher-order functions to reduce type-checker load
                for i in 0..<frameLength {
                    let sample: Float = channel0[i]
                    sumSquares += sample * sample
                }
                let meanSquare: Float = sumSquares / max(1, Float(frameLength))
                let rms: Float = sqrt(meanSquare)
                if rms > self.voiceAmplitudeThreshold {
                    // In always-on mode, only start silence timer after wake detected
                    if !self.alwaysOnListening || self.wakeDetected {
                        self.resetSilenceTimer()
                    }
                }
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()

        wakeDetected = false
        lastPartialText = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.lastPartialText = text

                if self.alwaysOnListening {
                    // Always-on mode: look for "hey pixo" wake phrase
                    let lower = text.lowercased()
                    let wakePhrases = ["hey pixo", "hey pico", "hey pixel", "a pixel", "hey pick so", "hey pics oh"]
                    let hasWake = wakePhrases.contains { lower.contains($0) }

                    if hasWake && !self.wakeDetected {
                        self.wakeDetected = true
                        DispatchQueue.main.async {
                            self.eventPublisher.send(.didStartListening)
                        }
                    }

                    if self.wakeDetected {
                        // Strip wake phrase and show the rest as transcription
                        let stripped = IntentRouter.stripWakePhrase(from: text)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        DispatchQueue.main.async {
                            self.transcribedText = stripped
                            self.eventPublisher.send(.didTranscribe(text: stripped, isFinal: result.isFinal))
                        }
                        // Reset silence timer — user is actively speaking after wake
                        self.resetSilenceTimer()
                    }
                } else {
                    // Legacy one-shot mode
                    DispatchQueue.main.async {
                        self.transcribedText = text
                        self.eventPublisher.send(.didTranscribe(text: text, isFinal: result.isFinal))
                    }
                }
            }
            if error != nil || result?.isFinal == true {
                if self.alwaysOnListening {
                    // Restart recognition loop automatically
                    self.restartListeningLoop()
                } else {
                    self.stopListening()
                }
            }
        }

        DispatchQueue.main.async {
            self.isListening = true
            // In always-on mode, don't emit didStartListening until wake detected
            if !self.alwaysOnListening {
                self.eventPublisher.send(.didStartListening)
            }
        }
    }

    func stopListening() {
        guard isListening else { return }

        silenceTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Signal no more audio — lets recognizer deliver a final result.
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Give the recognizer a brief chance to finish, then force-cancel.
        let task = recognitionTask
        recognitionTask = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            task?.cancel()
        }

        // Emit a synthetic final-transcription event so the ViewModel
        // can route whatever text has been recognised so far.
        let currentText = transcribedText
        DispatchQueue.main.async {
            self.isListening = false
            if !currentText.trimmingCharacters(in: .whitespaces).isEmpty {
                self.eventPublisher.send(.didTranscribe(text: currentText, isFinal: true))
            }
            self.eventPublisher.send(.didStopListening)
        }
    }

    // MARK: - Pause / Resume (for TTS playback)

    /// Temporarily suspends the microphone and recognition so that another
    /// AVAudioEngine (e.g. ElevenLabsService) can own the audio session.
    /// Call `resumeListening()` when TTS playback finishes.
    private(set) var isPaused = false

    func pauseListening() {
        guard isListening, !isPaused else { return }
        isPaused = true
        print("[Pixo] SpeechService: pausing STT for TTS playback")

        silenceTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        wakeDetected = false
        lastPartialText = ""
    }

    /// Restarts always-on listening after a TTS pause.
    func resumeListening() {
        guard isPaused else { return }
        isPaused = false
        print("[Pixo] SpeechService: resuming STT after TTS playback")

        // Small delay to let the audio session settle after playback stops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.alwaysOnListening else { return }
            self.isListening = false
            self.configureAudioSession()
            self.startListening()
        }
    }

    /// Restarts recognition seamlessly for always-on mode.
    /// Fires the current wake-detected text as final before restarting.
    private func restartListeningLoop() {
        silenceTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // If we had wake-detected text, emit it as final
        if wakeDetected {
            let stripped = IntentRouter.stripWakePhrase(from: lastPartialText)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                DispatchQueue.main.async {
                    self.eventPublisher.send(.didTranscribe(text: stripped, isFinal: true))
                    self.eventPublisher.send(.didStopListening)
                }
            }
        }

        // Brief pause then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.alwaysOnListening else { return }
            self.isListening = false
            self.startListening()
        }
    }

    private func resetSilenceTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.silenceTimer?.invalidate()
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceTimeout, repeats: false) { [weak self] _ in
                guard let self else { return }
                if self.alwaysOnListening {
                    // In always-on mode, silence after wake means utterance is done
                    self.restartListeningLoop()
                } else {
                    self.stopListening()
                }
            }
        }
    }

    // MARK: - TTS

    /// Speak text with an expressive voice. Pitch is modulated by emotion valence.
    func speak(_ text: String, pitchMultiplier: Float = 1.0, rateMultiplier: Float = 1.0) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        // Use Samantha (en-US) — warm, natural voice
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-compact")
                       ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.pitchMultiplier = max(0.5, min(2.0, pitchMultiplier))
        utterance.rate = max(AVSpeechUtteranceMinimumSpeechRate,
                             min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * rateMultiplier))
        utterance.volume = 0.9

        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .word)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.eventPublisher.send(.didStartSpeaking)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.eventPublisher.send(.didFinishSpeaking)
        }
    }

    /// Phoneme/viseme callback for lip sync animation.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                            willSpeakRangeOfSpeechString characterRange: NSRange,
                            utterance: AVSpeechUtterance) {
        // Map character position to a simple viseme index (0-9)
        // A full implementation would use AVSpeechSynthesisMarker (iOS 16+)
        let visemeIndex = Int.random(in: 0...9)
        let duration: TimeInterval = 0.08
        DispatchQueue.main.async {
            self.eventPublisher.send(.phoneme(viseme: visemeIndex, duration: duration))
        }
    }
}

