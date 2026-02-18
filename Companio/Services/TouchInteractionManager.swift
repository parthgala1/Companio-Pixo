import Foundation
import Combine
import SwiftUI

// MARK: - TouchInteractionManager

/// Centralized touch state machine.
/// Tracks duration, velocity, phase, and emits classified TouchEvents.
/// CompanionViewModel observes published state for progressive visual feedback.
final class TouchInteractionManager: ObservableObject {

    // MARK: - Singleton
    static let shared = TouchInteractionManager()

    // MARK: - Published State (observed by CompanionViewModel)
    @Published private(set) var phase: TouchPhase = .idle
    @Published private(set) var currentDuration: TimeInterval = 0
    @Published private(set) var normalizedTouchLocation: CGPoint = CGPoint(x: 0.5, y: 0.5)

    // MARK: - Event Publisher
    let touchEventSubject = PassthroughSubject<TouchEvent, Never>()

    // MARK: - Internal State
    private var touchStartTime: Date?
    private var isDragging = false
    private var dragSamples: [(point: CGPoint, time: Date)] = []
    private var durationUpdateTimer: Timer?

    // MARK: - Thresholds
    private let lightTapMax: TimeInterval = 0.2
    private let holdMax: TimeInterval = 0.6
    private let longPressMax: TimeInterval = 1.2
    private let petSampleThreshold: Int = 5
    private let petVelocityMax: CGFloat = 800   // pts/sec — above this is a swipe, not a pet

    // MARK: - Init
    private init() {}

    // MARK: - Touch Lifecycle

    /// Call when a finger first contacts the screen.
    /// - Parameter normalizedLocation: Touch position normalized to 0–1 via GeometryReader.
    func touchBegan(normalizedLocation: CGPoint) {
        touchStartTime = Date()
        self.normalizedLocation(normalizedLocation)
        isDragging = false
        dragSamples = []
        currentDuration = 0

        phase = .touching

        // Tick duration at ~20 Hz for progressive visual feedback
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let start = self.touchStartTime else { return }
            DispatchQueue.main.async {
                self.currentDuration = Date().timeIntervalSince(start)
            }
        }
    }

    /// Call on every drag update.
    /// - Parameters:
    ///   - normalizedLocation: Current normalized position.
    ///   - absoluteLocation: Raw pixel position for velocity math.
    func dragChanged(normalizedLocation: CGPoint, absoluteLocation: CGPoint) {
        self.normalizedLocation(normalizedLocation)
        let now = Date()
        dragSamples.append((point: absoluteLocation, time: now))

        // Classify as petting once enough smooth samples accumulate
        if !isDragging && dragSamples.count >= petSampleThreshold {
            let velocity = recentVelocity()
            if velocity < petVelocityMax {
                isDragging = true
                phase = .petting
            }
        }
    }

    /// Call when the finger lifts.
    func touchEnded() {
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = nil

        guard let start = touchStartTime else {
            resetToIdle()
            return
        }

        let duration = Date().timeIntervalSince(start)
        let velocity = recentVelocity()

        let event: TouchEvent
        if isDragging {
            event = TouchEvent(type: .petting, duration: duration, velocity: velocity, normalizedLocation: normalizedTouchLocation)
        } else {
            let type = classifyTapDuration(duration)
            event = TouchEvent(type: type, duration: duration, velocity: 0, normalizedLocation: normalizedTouchLocation)
        }
        touchEventSubject.send(event)

        // Brief releasing phase for bounce animation
        phase = .releasing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.resetToIdle()
        }
        touchStartTime = nil
        isDragging = false
        dragSamples = []
    }

    /// Call if the gesture is cancelled (e.g., system interrupt).
    func touchCancelled() {
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = nil

        // If was petting, still emit the event so emotion updates apply
        if isDragging, let start = touchStartTime {
            let duration = Date().timeIntervalSince(start)
            let event = TouchEvent(type: .petting, duration: duration, velocity: 0, normalizedLocation: normalizedTouchLocation)
            touchEventSubject.send(event)
        }

        resetToIdle()
        touchStartTime = nil
        isDragging = false
        dragSamples = []
    }

    // MARK: - Helpers

    private func normalizedLocation(_ loc: CGPoint) {
        normalizedTouchLocation = CGPoint(
            x: loc.x.clamped(to: 0...1),
            y: loc.y.clamped(to: 0...1)
        )
    }

    private func classifyTapDuration(_ duration: TimeInterval) -> TouchType {
        if duration <= lightTapMax     { return .lightTap }
        if duration <= holdMax         { return .hold }
        if duration <= longPressMax    { return .longPress }
        return .overHold
    }

    /// Velocity over the last few samples (pts/sec).
    private func recentVelocity() -> CGFloat {
        guard dragSamples.count >= 2 else { return 0 }

        // Use last 6 samples for smoothing
        let window = dragSamples.suffix(6)
        guard let first = window.first, let last = window.last else { return 0 }
        let dt = last.time.timeIntervalSince(first.time)
        guard dt > 0 else { return 0 }

        var totalDist: CGFloat = 0
        let arr = Array(window)
        for i in 1..<arr.count {
            let dx = arr[i].point.x - arr[i-1].point.x
            let dy = arr[i].point.y - arr[i-1].point.y
            totalDist += sqrt(dx * dx + dy * dy)
        }
        return totalDist / CGFloat(dt)
    }

    private func resetToIdle() {
        phase = .idle
        currentDuration = 0
    }
}

// MARK: - CGFloat Clamped

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
