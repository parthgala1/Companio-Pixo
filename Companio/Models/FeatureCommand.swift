import Foundation

// MARK: - FeatureCommand

/// All routable commands from the IntentRouter.
/// Play modes are temporary overlays — the EmotionEngine remains global.
enum FeatureCommand: Equatable {
    case copyMe
    case dance
    case guessMood
    case story
    case staringContest
    case compliment
    case roast
    case silentCompanion
    case stop
    case llm(String)   // Fallback: full text sent to LLM

    // MARK: - Display

    var displayName: String {
        switch self {
        case .copyMe:          return "Copy Me"
        case .dance:           return "Dance Mode"
        case .guessMood:       return "Guess My Mood"
        case .story:           return "Story Time"
        case .staringContest:  return "Staring Contest"
        case .compliment:      return "Compliment Mode"
        case .roast:           return "Roast Mode"
        case .silentCompanion: return "Silent Mode"
        case .stop:            return "Stop"
        case .llm:             return "Chat"
        }
    }

    var emoji: String {
        switch self {
        case .copyMe:          return "🪞"
        case .dance:           return "💃"
        case .guessMood:       return "🔮"
        case .story:           return "📖"
        case .staringContest:  return "👁️"
        case .compliment:      return "💝"
        case .roast:           return "🔥"
        case .silentCompanion: return "🌙"
        case .stop:            return "⏹️"
        case .llm:             return "💬"
        }
    }

    /// Whether this command starts a persistent mode (vs one-shot)
    var isPersistentMode: Bool {
        switch self {
        case .copyMe, .dance, .staringContest, .silentCompanion: return true
        default: return false
        }
    }

    static func == (lhs: FeatureCommand, rhs: FeatureCommand) -> Bool {
        switch (lhs, rhs) {
        case (.copyMe, .copyMe), (.dance, .dance), (.guessMood, .guessMood),
             (.story, .story), (.staringContest, .staringContest),
             (.compliment, .compliment), (.roast, .roast),
             (.silentCompanion, .silentCompanion), (.stop, .stop): return true
        case (.llm(let a), .llm(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - PlayModeEvent

/// Events that play modes emit to the EmotionEngine.
enum PlayModeEvent {
    case copyMode
    case danceMode
    case moodGuessCorrect
    case moodGuessIncorrect
    case storyMode
    case staringContestWin
    case staringContestLose
    case complimentGiven
    case roastMode
    case silentCompanion
}
