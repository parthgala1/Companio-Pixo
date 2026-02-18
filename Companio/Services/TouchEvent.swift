import Foundation
import SwiftUI

// MARK: - TouchType

/// Classification of a touch event by duration and gesture type.
enum TouchType: Equatable {
    case lightTap       // 0–0.2s
    case hold           // 0.2–0.6s
    case longPress      // 0.6–1.2s
    case overHold       // 1.2s+
    case petting        // Smooth drag
}

// MARK: - TouchEvent

/// A resolved touch event emitted when touch ends.
struct TouchEvent {
    let type: TouchType
    let duration: TimeInterval
    let velocity: CGFloat          // pts/sec for drags, 0 for taps
    let normalizedLocation: CGPoint // 0–1 in both axes
}

// MARK: - TouchPhase (State Machine)

enum TouchPhase: Equatable {
    case idle
    case touching       // Finger down, not yet classified
    case petting        // Smooth drag detected
    case releasing      // Finger lifted, bounce-back
}
