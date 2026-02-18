import Foundation

// MARK: - EmotionState

/// The core emotional state of the Companio agent.
/// All values are normalized and clamped to their respective ranges.
struct EmotionState: Codable, Equatable {
    /// Positive/negative affect. -1.0 = very negative, 1.0 = very positive.
    var valence: Double
    /// Level of activation/excitement. 0.0 = calm, 1.0 = highly aroused.
    var arousal: Double
    /// Available energy. 0.0 = exhausted, 1.0 = full energy.
    var energy: Double
    /// Cumulative bond with the user. Grows with interaction, decays slowly over time.
    var attachmentScore: Double
    /// How bored the companion is. Grows with inactivity, resets on interaction.
    var boredomLevel: Double

    // MARK: - Defaults

    static let `default` = EmotionState(
        valence: 0.3,
        arousal: 0.4,
        energy: 0.8,
        attachmentScore: 0.1,
        boredomLevel: 0.0
    )

    // MARK: - Clamped Mutators

    mutating func adjustValence(by delta: Double) {
        valence = (valence + delta).clamped(to: -1.0...1.0)
    }

    mutating func adjustArousal(by delta: Double) {
        arousal = (arousal + delta).clamped(to: 0.0...1.0)
    }

    mutating func adjustEnergy(by delta: Double) {
        energy = (energy + delta).clamped(to: 0.0...1.0)
    }

    mutating func adjustAttachment(by delta: Double) {
        attachmentScore = (attachmentScore + delta).clamped(to: 0.0...1.0)
    }

    mutating func adjustBoredom(by delta: Double) {
        boredomLevel = (boredomLevel + delta).clamped(to: 0.0...1.0)
    }

    // MARK: - Derived Properties

    /// Maps the 2D valence/arousal space to a dominant mood label.
    var dominantMood: MoodLabel {
        switch (valence, arousal) {
        case let (v, a) where v > 0.3 && a > 0.5:  return .excited
        case let (v, a) where v > 0.3 && a <= 0.5: return .happy
        case let (v, a) where v < -0.3 && a > 0.5: return .anxious
        case let (v, a) where v < -0.3 && a <= 0.5: return .sad
        case let (_, a) where a < 0.2:              return .sleepy
        default:                                     return .neutral
        }
    }

    /// Normalized excitement level (combination of arousal and energy).
    var excitementLevel: Double {
        ((arousal + energy) / 2.0).clamped(to: 0.0...1.0)
    }

    /// How "engaged" the companion is (inverse of boredom, boosted by attachment).
    var engagementLevel: Double {
        ((1.0 - boredomLevel) * 0.7 + attachmentScore * 0.3).clamped(to: 0.0...1.0)
    }
}

// MARK: - MoodLabel

enum MoodLabel: String, Codable {
    case excited
    case happy
    case neutral
    case anxious
    case sad
    case sleepy
}

// MARK: - Persistence Key

extension EmotionState {
    static let userDefaultsKey = "companio.emotionState"
}
