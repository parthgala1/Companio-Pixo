import SwiftUI

// MARK: - PixoEmote

/// The 12 distinct emotes Pixo can display, matching the reference emote sheet.
/// Each emote fully specifies eye styles, mouth state, brow tilt, and overlay elements.
enum PixoEmote: String, CaseIterable, Identifiable {
    case wink        // Playful wink + smile
    case happy       // Simple happy (oval eyes + smile)
    case confused    // Raised brows + "?" overlay
    case proud       // Slight smile + thumbs-up overlay
    case joyful      // Big eyes + wide smile
    case sad         // Round crying eyes + frown
    case singing     // Spiral eyes + music notes + wavy smile
    case shocked     // Wide round eyes + "O" mouth
    case lowBattery  // Spiral eyes + music notes + battery icon
    case laughing    // Squint eyes + "HA" text
    case sleeping    // Line eyes + "ZZZ" + small "o"
    case love        // Heart replaces entire face
    case charging    // Happy eyes + wide smile + charging battery overlay

    var id: String { rawValue }

    // MARK: - Eye Configuration

    var leftEyeStyle: EyeStyle {
        switch self {
        case .wink:       return .winkClosed
        case .happy:      return .normal
        case .confused:   return .normal
        case .proud:      return .normal
        case .joyful:     return .normal
        case .sad:        return .round
        case .singing:    return .spiral
        case .shocked:    return .round
        case .lowBattery: return .spiral
        case .laughing:   return .happySquint
        case .sleeping:   return .sleepLine
        case .love:       return .hidden
        case .charging:   return .normal
        }
    }

    var rightEyeStyle: EyeStyle {
        switch self {
        case .wink:       return .normal
        case .happy:      return .normal
        case .confused:   return .normal
        case .proud:      return .normal
        case .joyful:     return .normal
        case .sad:        return .round
        case .singing:    return .spiral
        case .shocked:    return .round
        case .lowBattery: return .spiral
        case .laughing:   return .happySquint
        case .sleeping:   return .sleepLine
        case .love:       return .hidden
        case .charging:   return .normal
        }
    }

    var mouthState: MouthState {
        switch self {
        case .wink:       return .smile
        case .happy:      return .smile
        case .confused:   return .smile
        case .proud:      return .neutral
        case .joyful:     return .smile
        case .sad:        return .wavyFrown
        case .singing:    return .wavySmile
        case .shocked:    return .surprise
        case .lowBattery: return .bored
        case .laughing:   return .frown      // inverted arc under squint eyes
        case .sleeping:   return .surprise   // small "O"
        case .love:       return .neutral    // hidden behind heart
        case .charging:   return .smile
        }
    }

    var browTilt: Double {
        switch self {
        case .wink:       return -0.2
        case .happy:      return 0.0
        case .confused:   return 0.35
        case .proud:      return -0.1
        case .joyful:     return -0.15
        case .sad:        return 0.5
        case .singing:    return 0.0
        case .shocked:    return -0.4
        case .lowBattery: return 0.0
        case .laughing:   return 0.0
        case .sleeping:   return 0.0
        case .love:       return 0.0
        case .charging:   return -0.15
        }
    }

    /// Whether the normal face (eyes + mouth) should be visible.
    var showsFace: Bool {
        self != .love
    }


    /// Whether eyebrows should be hidden for this emote.
    var hidesBrows: Bool {
        switch self {
        case .singing, .lowBattery, .laughing, .sleeping, .love:
            return true
        default:
            return false
        }
    }

    /// Pupil scale override (1.0 = default, >1 = dilated).
    var pupilScale: Double {
        switch self {
        case .joyful:     return 1.2
        case .shocked:    return 1.3
        case .sad:        return 0.9
        case .sleeping:   return 0.8
        case .charging:   return 1.1
        default:          return 1.0
        }
    }

    // MARK: - Overlay Elements

    var overlayElements: [EmoteOverlayElement] {
        switch self {
        case .confused:   return [.questionMark]
        case .proud:      return [.thumbsUp]
        case .sad:        return [.tears]
        case .singing:    return [.musicNotes]
        case .lowBattery: return [.musicNotes, .lowBattery]
        case .laughing:   return [.haText]
        case .sleeping:   return [.zzz]
        case .love:       return [.heart]
        case .charging:   return [.chargingBattery, .sparkle]
        default:          return []
        }
    }

    // MARK: - Mapping to BehaviorType

    /// Maps this emote to the closest existing BehaviorType for emotion engine compatibility.
    var behaviorType: BehaviorType {
        switch self {
        case .wink:       return .playful
        case .happy:      return .happy
        case .confused:   return .curious
        case .proud:      return .happy
        case .joyful:     return .excited
        case .sad:        return .sad
        case .singing:    return .playful
        case .shocked:    return .attentive
        case .lowBattery: return .sleepy
        case .laughing:   return .excited
        case .sleeping:   return .sleepy
        case .love:       return .happy
        case .charging:   return .happy
        }
    }
}

// MARK: - EyeStyle

/// Visual shape mode for a single eye.
enum EyeStyle: Equatable {
    case normal       // Rounded rectangle (default)
    case round        // Circle
    case spiral       // Swirl pattern
    case winkClosed   // Curved closed arc (^)
    case happySquint  // Upward arcs (laughing ∪)
    case sleepLine    // Horizontal line
    case hidden       // Invisible (love mode)
}

// MARK: - EmoteOverlayElement

/// Decorative overlay elements that accompany certain emotes.
enum EmoteOverlayElement: Equatable, Hashable {
    case questionMark
    case thumbsUp
    case tears
    case musicNotes
    case lowBattery
    case haText
    case zzz
    case heart

    // Expressiveness overlays (petting, affection, anger)
    case sparkle          // Tiny animated stars
    case tinyHeartsFloat  // Small hearts floating upward
    case blushWide        // Pink gradient under eyes
    case loveAura         // Warm radial glow ring
    case happyBounceLines // Speed lines around face
    case softHalo         // Gentle ring above head
    case angerPulse       // Red cross anger mark
    case hummingNote      // "~" above head
    case chargingBattery  // Green battery with lightning bolt
}

// MARK: - ActiveOverlay

/// An ephemeral overlay in the overlay stack (max 3 active at once).
/// Auto-expires after `duration`. Used for staggered emotional feedback.
struct ActiveOverlay: Identifiable, Equatable {
    let id: UUID
    let type: EmoteOverlayElement
    let duration: TimeInterval

    init(type: EmoteOverlayElement, duration: TimeInterval = 2.0) {
        self.id = UUID()
        self.type = type
        self.duration = duration
    }

    static func == (lhs: ActiveOverlay, rhs: ActiveOverlay) -> Bool {
        lhs.id == rhs.id
    }
}
