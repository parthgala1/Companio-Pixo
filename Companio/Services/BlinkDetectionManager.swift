import Foundation
import Combine

// MARK: - BlinkDetectionManager

/// Monitors face detection events to detect user blinks (brief face loss < 300ms).
/// Used by Staring Contest mode. Also suppresses Pixo's own blink scheduler during contest.
final class BlinkDetectionManager: ObservableObject {

    // MARK: - Singleton
    static let shared = BlinkDetectionManager()

    // MARK: - Publishers
    let userBlinkedPublisher = PassthroughSubject<Void, Never>()
    let pixoBlinkedPublisher = PassthroughSubject<Void, Never>()

    // MARK: - State
    @Published private(set) var isMonitoring = false
    @Published private(set) var pixoBlinkSuppressed = false

    // MARK: - Config
    private let blinkWindowSeconds: TimeInterval = 0.35   // Face loss < 350ms = blink
    private let pixoBlinkInterval: TimeInterval = 8.0     // Pixo "blinks" every 8s in contest

    // MARK: - Private
    private var faceLostTime: Date?
    private var pixoBlinkTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies
    private let faceDetectionService: FaceDetectionService

    // MARK: - Init
    private init(faceDetectionService: FaceDetectionService = .shared) {
        self.faceDetectionService = faceDetectionService
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        pixoBlinkSuppressed = true  // Suppress Pixo blinks during contest

        bindToFaceDetection()
        schedulePixoBlink()
    }

    func stopMonitoring() {
        isMonitoring = false
        pixoBlinkSuppressed = false
        pixoBlinkTimer?.invalidate()
        cancellables.removeAll()
        faceLostTime = nil
    }

    // MARK: - Face Detection Binding

    private func bindToFaceDetection() {
        // Face lost → record time
        faceDetectionService.faceLostPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.faceLostTime = Date()
            }
            .store(in: &cancellables)

        // Face redetected → check if it was a blink
        faceDetectionService.faceDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkForBlink()
            }
            .store(in: &cancellables)
    }

    private func checkForBlink() {
        guard let lostTime = faceLostTime else { return }
        let elapsed = Date().timeIntervalSince(lostTime)
        faceLostTime = nil

        if elapsed < blinkWindowSeconds {
            // Brief face loss = user blinked!
            userBlinkedPublisher.send()
        }
    }

    // MARK: - Pixo Blink Scheduling

    private func schedulePixoBlink() {
        // Pixo "blinks" after a random interval — if it fires first, Pixo loses
        let interval = Double.random(in: pixoBlinkInterval...(pixoBlinkInterval * 2))
        pixoBlinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self, self.isMonitoring else { return }
            self.pixoBlinkedPublisher.send()
        }
    }
}
