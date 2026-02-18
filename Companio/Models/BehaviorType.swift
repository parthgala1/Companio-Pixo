import Foundation

// MARK: - BehaviorType

/// Discrete behaviors the companion can exhibit.
/// Each behavior maps to a distinct animation + sound profile.
enum BehaviorType: String, CaseIterable, Codable {
    case idle
    case curious
    case happy
    case thinking
    case sleepy
    case excited
    case sad
    case attentive   // Eyes wide, tracking face closely
    case playful     // Quick eye movements, big smile

    // MARK: - Weighted Selection

    /// Selects a behavior using weighted randomness based on the current EmotionState.
    static func select(for state: EmotionState) -> BehaviorType {
        let candidates = weightedCandidates(for: state)
        let totalWeight = candidates.reduce(0.0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<totalWeight)
        for candidate in candidates {
            roll -= candidate.weight
            if roll <= 0 { return candidate.behavior }
        }
        return .idle
    }

    private static func weightedCandidates(for state: EmotionState) -> [(behavior: BehaviorType, weight: Double)] {
        let v = state.valence
        let a = state.arousal
        let e = state.energy
        let b = state.boredomLevel

        return [
            (.idle,      weight: max(0.1, b * 2.0 + (1.0 - a) * 1.5)),
            (.curious,   weight: max(0.1, a * 1.5 + (1.0 - abs(v)) * 1.0)),
            (.happy,     weight: max(0.1, v > 0 ? v * 2.5 : 0.1)),
            (.thinking,  weight: max(0.1, a * 0.8 + (1.0 - e) * 0.5)),
            (.sleepy,    weight: max(0.1, (1.0 - e) * 2.0 + (1.0 - a) * 1.0)),
            (.excited,   weight: max(0.1, v > 0 ? v * a * 3.0 : 0.1)),
            (.sad,       weight: max(0.1, v < 0 ? abs(v) * 2.0 : 0.05)),
            (.attentive, weight: max(0.1, state.attachmentScore * 1.5 + a * 0.5)),
            (.playful,   weight: max(0.1, v > 0.2 ? v * e * 2.0 : 0.1))
        ]
    }

    // MARK: - Animation Parameters

    /// Suggested blink rate multiplier for this behavior.
    var blinkRateMultiplier: Double {
        switch self {
        case .sleepy:    return 2.5   // Blinks more often (heavy lids)
        case .excited:   return 0.5   // Blinks less (wide-eyed)
        case .attentive: return 0.4
        case .thinking:  return 1.5
        default:         return 1.0
        }
    }

    /// Suggested pupil dilation factor.
    var pupilScale: Double {
        switch self {
        case .excited, .happy, .attentive: return 1.2
        case .sad, .sleepy:                return 0.8
        case .curious, .playful:           return 1.1
        default:                           return 1.0
        }
    }

    /// Mouth curvature: positive = smile, negative = frown.
    var mouthCurvature: Double {
        switch self {
        case .happy, .excited, .playful: return 0.8
        case .sad:                       return -0.6
        case .curious:                   return 0.1
        case .thinking:                  return -0.1
        default:                         return 0.2
        }
    }

    /// Sound cue to play when this behavior activates.
    var soundCue: SoundCue? {
        switch self {
        case .happy, .excited, .playful: return .happy
        case .thinking:                  return .thinking
        case .idle, .sleepy:             return .idle
        default:                         return nil
        }
    }
}

// MARK: - SoundCue

enum SoundCue: String {
    case blink    = "blink"
    case happy    = "happy"
    case thinking = "thinking"
    case idle     = "idle"
}
