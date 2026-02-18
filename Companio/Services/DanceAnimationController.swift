import Foundation
import Combine

// MARK: - DanceAnimationController

/// Drives rhythmic bounce animation at 120 BPM.
/// Publishes beat-synchronized offsets for eyes and mouth.
final class DanceAnimationController: ObservableObject {

    // MARK: - Singleton
    static let shared = DanceAnimationController()

    // MARK: - Published
    @Published private(set) var isActive = false
    @Published private(set) var bounceOffset: Double = 0.0    // -1.0 to 1.0 vertical bounce
    @Published private(set) var eyeSquishY: Double = 1.0      // Eye vertical scale
    @Published private(set) var mouthBounceCurvature: Double = 0.5

    // MARK: - Beat Config
    private let bpm: Double = 120.0
    private var beatInterval: TimeInterval { 60.0 / bpm }

    // MARK: - Timers
    private var beatTimer: Timer?
    private var energyDecayTimer: Timer?
    private var beatPhase: Int = 0

    // MARK: - Dependencies
    private let emotionEngine: EmotionEngine
    private let soundService: SoundService

    // MARK: - Init
    private init(emotionEngine: EmotionEngine = .shared,
                 soundService: SoundService = .shared) {
        self.emotionEngine = emotionEngine
        self.soundService = soundService
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        beatPhase = 0
        emotionEngine.onPlayModeEvent(.danceMode)
        soundService.play(.idle, emotionState: emotionEngine.state) // dance_loop placeholder

        startBeatTimer()
        startEnergyDecay()
    }

    func stop() {
        isActive = false
        beatTimer?.invalidate()
        energyDecayTimer?.invalidate()
        // Reset to neutral — views animate via @Published observation
        bounceOffset = 0.0
        eyeSquishY = 1.0
        mouthBounceCurvature = 0.5
    }

    // MARK: - Beat Animation

    private func startBeatTimer() {
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval / 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        beatPhase = (beatPhase + 1) % 4
        let energy = emotionEngine.state.energy

        switch beatPhase {
        case 0: // Down beat
            bounceOffset = -0.15 * energy
            eyeSquishY = 0.85
            mouthBounceCurvature = 0.8
        case 1: // Up
            bounceOffset = 0.1 * energy
            eyeSquishY = 1.1
            mouthBounceCurvature = 0.5
        case 2: // Down (softer)
            bounceOffset = -0.08 * energy
            eyeSquishY = 0.92
            mouthBounceCurvature = 0.7
        case 3: // Rest
            bounceOffset = 0.0
            eyeSquishY = 1.0
            mouthBounceCurvature = 0.6
        default:
            break
        }
    }

    // MARK: - Energy Decay

    private func startEnergyDecay() {
        energyDecayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, self.isActive else { return }
            // Energy slowly drains while dancing
            self.emotionEngine.onDanceEnergyDecay()
            // Auto-stop if exhausted
            if self.emotionEngine.state.energy < 0.1 {
                self.stop()
            }
        }
    }
}
