import Foundation

// MARK: - MoodClassifier

/// Classifies user mood from face detection signals and speech sentiment.
enum MoodClassifier {

    /// Classify mood from available signals.
    /// - Parameters:
    ///   - smileProbability: 0.0 (no smile) to 1.0 (big smile). Pass nil if unavailable.
    ///   - sentimentScore: -1.0 to 1.0 from speech analysis.
    ///   - arousal: Current arousal from EmotionState.
    /// - Returns: Predicted MoodType.
    static func classify(smileProbability: Double?,
                         sentimentScore: Double,
                         arousal: Double) -> MoodType {
        let smile = smileProbability ?? 0.5  // Default to neutral if unavailable

        // Weighted score: smile is strongest signal
        let positivity = smile * 0.5 + max(0, sentimentScore) * 0.3 + arousal * 0.2
        let negativity = max(0, -sentimentScore) * 0.5 + (1.0 - smile) * 0.3

        if positivity > 0.65 && arousal > 0.6 {
            return .excited
        } else if positivity > 0.5 {
            return .happy
        } else if negativity > 0.5 {
            return .stressed
        } else {
            return .neutral
        }
    }

    /// Generate a question Pixo asks the user to confirm the mood guess.
    static func confirmationQuestion(for mood: MoodType) -> String {
        switch mood {
        case .happy:    return "You seem happy right now! Am I right? 😊"
        case .excited:  return "You're giving me excited vibes! Is that right? 🤩"
        case .neutral:  return "You seem pretty chill. Am I reading you right? 😐"
        case .stressed: return "Hmm, you seem a little stressed. Did I get that right? 😤"
        }
    }

    /// Response when Pixo guesses correctly.
    static func correctResponse(for mood: MoodType) -> String {
        switch mood {
        case .happy:    return "Yes! I knew it — your happiness is contagious! 🌟"
        case .excited:  return "I can feel your energy from here! Let's ride it! ⚡"
        case .neutral:  return "Chill is good. I'm here for it. 😌"
        case .stressed: return "I see you. Let's take a breath together. 💙"
        }
    }

    /// Response when Pixo guesses incorrectly.
    static func incorrectResponse() -> String {
        let responses = [
            "Oops! My face-reading skills need work. 😅",
            "Ha! Got it wrong. I'll do better next time! 🙈",
            "Hmm, you're harder to read than I thought! 🤔"
        ]
        return responses.randomElement()!
    }
}
