import Foundation
import AVFoundation

// MARK: - ElevenLabsService

/// Converts text to speech using the ElevenLabs REST API.
/// Falls back to system TTS (SpeechService) on any error.
/// Streams audio via AVAudioEngine with amplitude-based mouth sync.
final class ElevenLabsService: ObservableObject {

    // MARK: - Singleton
    static let shared = ElevenLabsService()

    // MARK: - Config
    static let apiKeyKeychainKey = "companio.elevenlabs.apiKey"
    static let defaultVoiceID = "EXAVITQu4vr4xnSDxMaL"  // "Bella" — warm, expressive

    @Published var voiceID: String = ElevenLabsService.defaultVoiceID
    @Published private(set) var isSpeaking = false

    // MARK: - Audio Engine
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    // MARK: - Cancellation
    private var currentTask: Task<Void, Never>?

    // MARK: - Init
    private init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        try? audioEngine.start()
    }

    // MARK: - Speak

    /// Speaks text using ElevenLabs. Falls back to system TTS on failure.
    func speak(_ text: String,
               emotionState: EmotionState,
               fallback: SpeechService = .shared) {
        currentTask?.cancel()
        currentTask = Task {
            await speakAsync(text, emotionState: emotionState, fallback: fallback)
        }
    }

    func stopSpeaking() {
        currentTask?.cancel()
        playerNode.stop()
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    // MARK: - Async Implementation

    @MainActor
    private func speakAsync(_ text: String,
                             emotionState: EmotionState,
                             fallback: SpeechService) async {
        guard let apiKey = KeychainManager.shared.load(key: ElevenLabsService.apiKeyKeychainKey),
              !apiKey.isEmpty else {
            // No ElevenLabs key — use system TTS
            print("[Pixo] No ElevenLabs key — falling back to system TTS")
            let pitch = Float(1.0 + emotionState.valence * 0.15)
            let rate = Float(0.9 + emotionState.arousal * 0.15)
            fallback.speak(text, pitchMultiplier: pitch, rateMultiplier: rate)
            return
        }

        // Ensure audio session is ready for playback
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default,
                                  options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        isSpeaking = true
        defer { isSpeaking = false }

        do {
            print("[Pixo] Fetching ElevenLabs audio...")
            let audioData = try await fetchAudio(text: text, apiKey: apiKey, emotionState: emotionState)
            guard !Task.isCancelled else { return }
            print("[Pixo] Playing ElevenLabs audio (\(audioData.count) bytes)")
            try await playAudio(audioData)
            print("[Pixo] ElevenLabs playback finished")
        } catch {
            print("[Pixo] ElevenLabs error: \(error). Falling back to system TTS.")
            let pitch = Float(1.0 + emotionState.valence * 0.15)
            let rate = Float(0.9 + emotionState.arousal * 0.15)
            fallback.speak(text, pitchMultiplier: pitch, rateMultiplier: rate)
        }
    }

    // MARK: - API Call

    private func fetchAudio(text: String, apiKey: String, emotionState: EmotionState) async throws -> Data {
        // output_format must be a query parameter, not in the JSON body
        var components = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
        components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]
        let url = components.url!

        // Emotion-conditioned voice settings
        let stability = 0.4 + emotionState.arousal * 0.3       // Higher arousal = less stable (more expressive)
        let similarityBoost = 0.75
        let speakingRate = emotionState.valence > 0.3 ? 1.1 : (emotionState.arousal < 0.3 ? 0.85 : 1.0)

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2",
            "voice_settings": [
                "stability": stability,
                "similarity_boost": similarityBoost,
                "style": max(0.0, emotionState.valence * 0.5),
                "use_speaker_boost": true
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        _ = speakingRate  // Used in future streaming implementation

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ElevenLabsError.badResponse
        }
        return data
    }

    // MARK: - Audio Playback

    private func playAudio(_ data: Data) async throws {
        // Write to temp file for AVAudioFile
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard let audioFile = try? AVAudioFile(forReading: tempURL) else {
            throw ElevenLabsError.audioDecodeError
        }

        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                             frameCapacity: frameCount) else {
            throw ElevenLabsError.audioDecodeError
        }
        try audioFile.read(into: buffer)

        // Reconfigure audio engine with the decoded format to avoid mismatches
        // (SpeechService may have reclaimed the audio session since init)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default,
                                  options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        // Reconnect with the buffer's actual format
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode,
                            format: audioFile.processingFormat)

        if !audioEngine.isRunning { try audioEngine.start() }

        // Amplitude-based mouth sync
        startAmplitudeMouthSync(buffer: buffer)

        return await withCheckedContinuation { continuation in
            playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                continuation.resume()
            }
            playerNode.play()
        }
    }

    // MARK: - Mouth Sync

    /// Approximates mouth openness from audio buffer amplitude.
    private func startAmplitudeMouthSync(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let chunkSize = 1024
        var offset = 0

        // Schedule timer on main thread so it has a RunLoop
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                guard offset < frameLength else {
                    timer.invalidate()
                    NotificationCenter.default.post(
                        name: .companioMouthOpenness,
                        object: nil,
                        userInfo: ["openness": 0.0]
                    )
                    return
                }
                let end = min(offset + chunkSize, frameLength)
                let chunk = Array(UnsafeBufferPointer(start: channelData + offset, count: end - offset))
                let rms = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
                let openness = Double(min(rms * 8.0, 1.0))
                NotificationCenter.default.post(
                    name: .companioMouthOpenness,
                    object: nil,
                    userInfo: ["openness": openness]
                )
                offset = end
            }
        }
    }
}

// MARK: - ElevenLabsError

enum ElevenLabsError: Error {
    case badResponse
    case audioDecodeError
}

// MARK: - KeychainManager Extension

extension KeychainManager {
    static let elevenLabsAPIKeyKey = ElevenLabsService.apiKeyKeychainKey

    func saveElevenLabsAPIKey(_ key: String) {
        save(key: ElevenLabsService.apiKeyKeychainKey, value: key)
    }

    func loadElevenLabsAPIKey() -> String? {
        load(key: ElevenLabsService.apiKeyKeychainKey)
    }
}
