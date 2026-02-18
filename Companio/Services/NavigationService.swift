import Foundation
import Combine

// MARK: - RouteEvent

/// A navigation instruction that can modulate the companion's emotional state.
struct RouteEvent {
    enum ManeuverType {
        case turnLeft, turnRight, continueAhead, uturn, arrive, rerouting
    }

    let instruction: String
    let distanceMeters: Double
    let maneuver: ManeuverType
    let isUrgent: Bool
}

// MARK: - NavigationService

/// Placeholder service for future Google Maps / navigation integration.
/// Receives route events and maps them to emotional modulations.
final class NavigationService: ObservableObject {

    // MARK: - Singleton
    static let shared = NavigationService()

    // MARK: - Publishers
    let routeEventPublisher = PassthroughSubject<RouteEvent, Never>()

    @Published private(set) var isNavigating = false
    @Published private(set) var currentInstruction: String?

    // MARK: - Dependency
    private let emotionEngine: EmotionEngine

    // MARK: - Init
    private init(emotionEngine: EmotionEngine = .shared) {
        self.emotionEngine = emotionEngine
    }

    // MARK: - Route Event Injection

    /// Inject a navigation event. Modulates emotion based on maneuver urgency.
    func injectRouteEvent(_ event: RouteEvent) {
        currentInstruction = event.instruction
        routeEventPublisher.send(event)

        // Map navigation events to emotional modulation
        switch event.maneuver {
        case .arrive:
            // Arriving somewhere is positive
            emotionEngine.onPositiveOutcome()
        case .rerouting:
            // Rerouting is slightly stressful
            emotionEngine.onNegativeOutcome()
        case .uturn:
            // U-turns are mildly alarming
            emotionEngine.onSpeechSentiment(-0.2)
        case .turnLeft, .turnRight:
            if event.isUrgent {
                emotionEngine.onFaceDetected(proximity: 0.8, offset: 0)
            }
        case .continueAhead:
            // Calm, steady state
            break
        }
    }

    func startNavigation() {
        isNavigating = true
    }

    func stopNavigation() {
        isNavigating = false
        currentInstruction = nil
    }
}
