import Foundation
import Combine

// MARK: - EmotionEngine

/// The heart of Companio. Manages the persistent emotional state and exposes
/// update methods for all event sources (face detection, speech, time, interaction).
final class EmotionEngine: ObservableObject {

    // MARK: - Singleton
    static let shared = EmotionEngine()

    // MARK: - Published State
    @Published private(set) var state: EmotionState

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    private var boredomTimer: Timer?
    private var timeOfDayTimer: Timer?
    private var emotionDecayTimer: Timer?

    // MARK: - Init
    private init() {
        self.state = EmotionEngine.loadPersistedState()
        startBoredomTimer()
        startTimeOfDayModulation()
        startEmotionDecayTimer()
    }

    // MARK: - Event Handlers

    /// Called when a face is detected in frame.
    /// - Parameters:
    ///   - proximity: 0.0 (far) to 1.0 (very close)
    ///   - offset: horizontal offset from center, -1.0 to 1.0
    func onFaceDetected(proximity: Double, offset: Double) {
        update { state in
            // Presence of a face is stimulating
            state.adjustArousal(by: proximity * 0.08)
            state.adjustValence(by: 0.04)
            state.adjustBoredom(by: -0.15)
            state.adjustAttachment(by: 0.005)
        }
    }

    /// Called when face tracking is lost.
    func onFaceLost() {
        update { state in
            state.adjustArousal(by: -0.05)
            state.adjustBoredom(by: 0.05)
        }
    }

    /// Called with a sentiment score from speech analysis.
    /// - Parameter score: -1.0 (very negative) to 1.0 (very positive)
    func onSpeechSentiment(_ score: Double) {
        update { state in
            // Sentiment directly shifts valence, with dampening
            state.adjustValence(by: score * 0.15)
            // Positive speech is energizing
            if score > 0 {
                state.adjustEnergy(by: score * 0.05)
                state.adjustArousal(by: score * 0.08)
            }
        }
    }

    /// Called whenever the user interacts (speaks, taps, etc.)
    func onInteraction() {
        update { state in
            state.adjustBoredom(by: -0.3)
            state.adjustArousal(by: 0.1)
            state.adjustAttachment(by: 0.01)
        }
    }

    /// Called when the companion successfully helps the user.
    func onPositiveOutcome() {
        update { state in
            state.adjustValence(by: 0.2)
            state.adjustArousal(by: 0.1)
            state.adjustAttachment(by: 0.02)
        }
    }

    /// Called on LLM error or failed interaction.
    func onNegativeOutcome() {
        update { state in
            state.adjustValence(by: -0.1)
            state.adjustArousal(by: 0.05)
        }
    }

    /// Called by play mode features to update emotional state.
    func onPlayModeEvent(_ event: PlayModeEvent) {
        update { state in
            switch event {
            case .copyMode:
                state.adjustArousal(by: 0.08)
                state.adjustAttachment(by: 0.02)
                state.adjustBoredom(by: -0.2)

            case .danceMode:
                state.adjustArousal(by: 0.2)
                state.adjustValence(by: 0.1)
                state.adjustBoredom(by: -0.4)

            case .moodGuessCorrect:
                state.adjustValence(by: 0.15)
                state.adjustArousal(by: 0.1)
                state.adjustAttachment(by: 0.05)
                state.adjustBoredom(by: -0.3)

            case .moodGuessIncorrect:
                // Playful embarrassment — slight negative valence, stays engaged
                state.adjustValence(by: -0.05)
                state.adjustArousal(by: 0.05)
                state.adjustAttachment(by: 0.01)

            case .storyMode:
                state.adjustValence(by: 0.1)
                state.adjustArousal(by: 0.05)
                state.adjustBoredom(by: -0.25)

            case .staringContestWin:
                state.adjustValence(by: 0.2)
                state.adjustArousal(by: 0.15)
                state.adjustAttachment(by: 0.03)

            case .staringContestLose:
                state.adjustValence(by: -0.08)
                state.adjustArousal(by: 0.1)

            case .complimentGiven:
                state.adjustValence(by: 0.1)
                state.adjustAttachment(by: 0.03)
                state.adjustBoredom(by: -0.1)

            case .roastMode:
                state.adjustArousal(by: 0.12)
                state.adjustValence(by: 0.05)
                state.adjustBoredom(by: -0.2)

            case .silentCompanion:
                state.adjustArousal(by: -0.1)
                state.adjustAttachment(by: 0.02)
                state.adjustBoredom(by: -0.05)
            }
        }
    }


    // MARK: - Time-Based Modulation

    private func startBoredomTimer() {
        // Boredom grows every 30 seconds of inactivity
        boredomTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.update { state in
                state.adjustBoredom(by: 0.04)
                state.adjustEnergy(by: -0.01)
                // Bored companions get slightly less aroused
                if state.boredomLevel > 0.5 {
                    state.adjustArousal(by: -0.02)
                }
            }
        }
    }

    private func startTimeOfDayModulation() {
        // Apply time-of-day modulation every 5 minutes
        timeOfDayTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.applyTimeOfDayModulation()
        }
        // Apply immediately on launch
        applyTimeOfDayModulation()
    }

    private func applyTimeOfDayModulation() {
        let hour = Calendar.current.component(.hour, from: Date())
        update { state in
            switch hour {
            case 6..<9:   // Morning: gradually waking up
                state.adjustEnergy(by: 0.02)
                state.adjustArousal(by: 0.01)
            case 9..<12:  // Mid-morning: peak energy
                state.adjustEnergy(by: 0.01)
                state.adjustValence(by: 0.01)
            case 12..<14: // Post-lunch: slight dip
                state.adjustEnergy(by: -0.01)
                state.adjustArousal(by: -0.01)
            case 14..<18: // Afternoon: stable
                break
            case 18..<21: // Evening: winding down
                state.adjustEnergy(by: -0.01)
            case 21..<24, 0..<6: // Night: sleepy
                state.adjustEnergy(by: -0.02)
                state.adjustArousal(by: -0.02)
            default:
                break
            }
        }
    }

    /// Called by DanceAnimationController every 5s to drain energy while dancing.
    func onDanceEnergyDecay() {
        update { state in
            state.adjustEnergy(by: -0.01)
        }
    }

    // MARK: - Touch-Based Emotional Modulation

    /// Modulates emotion state based on a classified touch event.
    /// Light touches are positive; prolonged presses shift toward irritation.
    /// Petting is strongly positive.
    func onTouchEvent(_ event: TouchEvent) {
        update { state in
            switch event.type {
            case .lightTap:
                state.adjustValence(by: 0.08)
                state.adjustArousal(by: 0.05)
                state.adjustBoredom(by: -0.15)
                state.adjustAttachment(by: 0.005)

            case .hold:
                // Curious, mildly stimulating
                state.adjustArousal(by: 0.1)
                state.adjustBoredom(by: -0.2)

            case .longPress:
                // Duration-weighted irritation
                let intensityFactor = event.duration * 0.3
                state.adjustValence(by: -intensityFactor)
                state.adjustArousal(by: event.duration * 0.2)
                state.adjustBoredom(by: -0.1)

            case .overHold:
                // Strong negative — anger zone
                let intensityFactor = min(event.duration * 0.3, 0.5)
                state.adjustValence(by: -intensityFactor)
                state.adjustArousal(by: min(event.duration * 0.2, 0.4))
                state.adjustBoredom(by: -0.1)

            case .petting:
                // Warm, bonding
                state.adjustValence(by: 0.2)
                state.adjustArousal(by: -0.05)  // calming
                state.adjustAttachment(by: 0.03)
                state.adjustBoredom(by: -0.1)
                state.adjustEnergy(by: 0.05)
            }
        }
    }

    // MARK: - Emotion Decay (Gradual Return to Baseline)

    /// Slowly drifts emotion values toward their baseline so anger/excitement
    /// doesn't persist forever. Rate: ~0.02 per second.
    private func startEmotionDecayTimer() {
        emotionDecayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update { state in
                let valenceBaseline = 0.3
                let arousalBaseline = 0.4

                // Move toward baseline at 0.02/sec
                let vDelta = valenceBaseline - state.valence
                if abs(vDelta) > 0.01 {
                    state.adjustValence(by: vDelta > 0 ? 0.02 : -0.02)
                }

                let aDelta = arousalBaseline - state.arousal
                if abs(aDelta) > 0.01 {
                    state.adjustArousal(by: aDelta > 0 ? 0.02 : -0.02)
                }
            }
        }
    }

    // MARK: - Behavior Selection

    /// Returns the most appropriate behavior for the current state.
    func selectBehavior() -> BehaviorType {
        BehaviorType.select(for: state)
    }

    // MARK: - Persistence

    func persist() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: EmotionState.userDefaultsKey)
        }
    }

    private static func loadPersistedState() -> EmotionState {
        guard let data = UserDefaults.standard.data(forKey: EmotionState.userDefaultsKey),
              let state = try? JSONDecoder().decode(EmotionState.self, from: data) else {
            return .default
        }
        return state
    }

    // MARK: - Private Helpers

    /// Thread-safe state mutation that also persists and publishes.
    private func update(_ mutation: @escaping (inout EmotionState) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            mutation(&self.state)
            self.persist()
        }
    }

    /// Resets all emotion state to defaults. Called from Settings.
    func resetState() {
        update { state in
            state = .default
        }
    }
}

