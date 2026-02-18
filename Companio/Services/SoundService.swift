import Foundation
import AVFoundation

// MARK: - SoundService

/// Plays short expressive sound cues with emotion-dependent pitch modulation.
final class SoundService: ObservableObject {

    // MARK: - Singleton
    static let shared = SoundService()

    // MARK: - Audio Engine
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let pitchEffect = AVAudioUnitTimePitch()

    // MARK: - Buffers
    private var soundBuffers: [SoundCue: AVAudioPCMBuffer] = [:]

    // MARK: - Init
    private init() {
        setupEngine()
        preloadSounds()
    }

    // MARK: - Setup

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(pitchEffect)

        // Chain: player → pitch → main mixer → output
        engine.connect(playerNode, to: pitchEffect, format: nil)
        engine.connect(pitchEffect, to: engine.mainMixerNode, format: nil)

        try? engine.start()
    }

    private func preloadSounds() {
        for cue in [SoundCue.blink, .happy, .thinking, .idle] {
            if let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
               let file = try? AVAudioFile(forReading: url),
               let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                              frameCapacity: AVAudioFrameCount(file.length)) {
                try? file.read(into: buffer)
                soundBuffers[cue] = buffer
            }
        }
    }

    // MARK: - Playback

    /// Play a sound cue with pitch modulated by the current emotion state.
    func play(_ cue: SoundCue, emotionState: EmotionState? = nil) {
        guard let buffer = soundBuffers[cue] else {
            // Sound file not found — silently skip (stubs not yet replaced)
            return
        }

        // Pitch: valence shifts pitch up/down, arousal adds a slight speed boost
        if let state = emotionState {
            let pitchCents = Float(state.valence * 200.0)  // ±200 cents (±2 semitones)
            let rateFactor = Float(1.0 + state.arousal * 0.1)
            pitchEffect.pitch = pitchCents
            pitchEffect.rate = rateFactor
        } else {
            pitchEffect.pitch = 0
            pitchEffect.rate = 1.0
        }

        if !engine.isRunning { try? engine.start() }

        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
        playerNode.play()
    }

    /// Play the blink sound (called by animation system).
    func playBlink(emotionState: EmotionState? = nil) {
        play(.blink, emotionState: emotionState)
    }
}
