import Foundation
import Combine

// MARK: - EmotionViewModel

/// Exposes EmotionEngine state to Views and drives behavior transitions.
final class EmotionViewModel: ObservableObject {

    // MARK: - Published
    @Published private(set) var state: EmotionState
    @Published private(set) var currentBehavior: BehaviorType = .idle
    @Published private(set) var expressionBlend: ExpressionBlend = .neutral

    // MARK: - Dependencies
    private let emotionEngine: EmotionEngine
    private let soundService: SoundService

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    private var previousBehavior: BehaviorType = .idle

    // MARK: - Init
    init(emotionEngine: EmotionEngine = .shared, soundService: SoundService = .shared) {
        self.emotionEngine = emotionEngine
        self.soundService = soundService
        self.state = emotionEngine.state
        bindToEngine()
    }

    // MARK: - Bindings

    private func bindToEngine() {
        emotionEngine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                self.state = newState
                self.updateDerivedState(from: newState)
            }
            .store(in: &cancellables)
    }

    private func updateDerivedState(from state: EmotionState) {
        let newBehavior = emotionEngine.selectBehavior()
        expressionBlend = ExpressionBlend(from: state)

        if newBehavior != previousBehavior {
            currentBehavior = newBehavior
            // Play sound on behavior transition
            if let cue = newBehavior.soundCue {
                soundService.play(cue, emotionState: state)
            }
            previousBehavior = newBehavior
        }
    }

    // MARK: - Debug / Display Helpers

    var moodLabel: String { state.dominantMood.rawValue.capitalized }
    var valenceDisplay: String { String(format: "%.2f", state.valence) }
    var arousalDisplay: String { String(format: "%.2f", state.arousal) }
    var energyDisplay: String { String(format: "%.2f", state.energy) }
    var boredomDisplay: String { String(format: "%.2f", state.boredomLevel) }
}

// MARK: - ExpressionBlend

/// Derived display parameters computed from EmotionState.
struct ExpressionBlend {
    let smileIntensity: Double    // 0.0 to 1.0
    let eyeOpenness: Double       // 0.0 to 1.0
    let eyebrowRaise: Double      // 0.0 to 1.0
    let blushIntensity: Double    // 0.0 to 1.0

    static let neutral = ExpressionBlend(
        smileIntensity: 0.3,
        eyeOpenness: 0.9,
        eyebrowRaise: 0.5,
        blushIntensity: 0.0
    )

    init(smileIntensity: Double, eyeOpenness: Double, eyebrowRaise: Double, blushIntensity: Double) {
        self.smileIntensity = smileIntensity
        self.eyeOpenness = eyeOpenness
        self.eyebrowRaise = eyebrowRaise
        self.blushIntensity = blushIntensity
    }

    init(from state: EmotionState) {
        smileIntensity = max(0, state.valence).clamped(to: 0.0...1.0)
        eyeOpenness = (0.5 + state.arousal * 0.5).clamped(to: 0.3...1.0)
        eyebrowRaise = state.arousal.clamped(to: 0.0...1.0)
        blushIntensity = (state.valence > 0.5 ? (state.valence - 0.5) * 2.0 : 0.0).clamped(to: 0.0...1.0)
    }
}

