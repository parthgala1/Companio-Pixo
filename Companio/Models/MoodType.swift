import Foundation

// MARK: - MoodType

/// Predicted mood categories used by the Guess My Mood game.
enum MoodType: String, CaseIterable {
    case happy    = "happy"
    case excited  = "excited"
    case neutral  = "neutral"
    case stressed = "stressed"

    var emoji: String {
        switch self {
        case .happy:    return "😊"
        case .excited:  return "🤩"
        case .neutral:  return "😐"
        case .stressed: return "😤"
        }
    }

    var description: String {
        switch self {
        case .happy:    return "You seem happy!"
        case .excited:  return "You're excited about something!"
        case .neutral:  return "You seem pretty chill right now."
        case .stressed: return "You seem a little stressed."
        }
    }
}

// MARK: - MoodGuessState

/// State machine for the Guess My Mood game flow.
enum MoodGuessState: Equatable {
    case idle
    case analyzing
    case presenting(prediction: MoodType)
    case confirmed(correct: Bool)
}
