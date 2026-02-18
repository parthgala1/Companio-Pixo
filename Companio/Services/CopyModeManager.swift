import Foundation
import Combine

// MARK: - CopyModeManager

/// Mirrors the user's facial expression in real-time.
/// Subscribes to FaceDetectionService and publishes expression overrides.
final class CopyModeManager: ObservableObject {

    // MARK: - Singleton
    static let shared = CopyModeManager()

    // MARK: - Published
    @Published private(set) var isActive = false
    @Published private(set) var mirroredCurvature: Double = 0.2   // Mouth curvature to mirror
    @Published private(set) var mirroredTiltOffset: CGPoint = .zero // Head tilt → pupil offset

    // MARK: - Dependencies
    private let faceDetectionService: FaceDetectionService
    private let emotionEngine: EmotionEngine

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    private var autoStopTimer: Timer?

    // MARK: - Init
    private init(faceDetectionService: FaceDetectionService = .shared,
                 emotionEngine: EmotionEngine = .shared) {
        self.faceDetectionService = faceDetectionService
        self.emotionEngine = emotionEngine
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        emotionEngine.onPlayModeEvent(.copyMode)
        bindToFaceDetection()

        // Auto-stop after 30 seconds
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    func stop() {
        isActive = false
        autoStopTimer?.invalidate()
        cancellables.removeAll()
        // Reset to neutral
        mirroredCurvature = 0.2
        mirroredTiltOffset = .zero
    }

    // MARK: - Face Mirroring

    private func bindToFaceDetection() {
        faceDetectionService.faceDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.mirrorFace(event)
            }
            .store(in: &cancellables)
    }

    private func mirrorFace(_ event: FaceEvent) {
        // Mirror horizontal offset as head tilt
        let tiltX = event.horizontalOffset * 0.25
        let tiltY = (event.normalizedCenter.y - 0.5) * 0.2
        mirroredTiltOffset = CGPoint(x: tiltX, y: tiltY)

        // Approximate smile from bounding box aspect ratio
        // Wider box relative to height suggests a smile
        let aspectRatio = event.boundingBox.width / max(event.boundingBox.height, 0.001)
        let smileEstimate = (aspectRatio - 0.7).clamped(to: 0.0...0.6) / 0.6
        mirroredCurvature = smileEstimate * 0.8 - 0.1  // Map to -0.1...0.7
    }
}
