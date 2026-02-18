import Foundation
import AVFoundation
import Vision
import Combine

// MARK: - FaceEvent

/// Data emitted when a face is detected.
struct FaceEvent {
    /// Normalized center of the face bounding box (0,0 = top-left, 1,1 = bottom-right).
    let normalizedCenter: CGPoint
    /// How close the face is: 0.0 = far, 1.0 = very close (based on bounding box area).
    let proximityRatio: Double
    /// Horizontal offset from screen center: -1.0 = far left, 1.0 = far right.
    let horizontalOffset: Double
    /// Raw bounding box in normalized image coordinates.
    let boundingBox: CGRect
}

// MARK: - FaceDetectionService

/// Manages the front camera session and runs Vision face detection.
/// Emits `FaceEvent` via Combine. Throttled to ~10 fps to conserve CPU.
final class FaceDetectionService: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = FaceDetectionService()

    // MARK: - Publishers
    let faceDetectedPublisher = PassthroughSubject<FaceEvent, Never>()
    let faceLostPublisher = PassthroughSubject<Void, Never>()

    @Published private(set) var isRunning = false
    @Published private(set) var lastFaceEvent: FaceEvent?

    // MARK: - Private
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "companio.facedetection.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "companio.facedetection.processing", qos: .utility)

    // Throttle: only process a frame every ~100ms (10 fps)
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.1

    private var faceRequest: VNDetectFaceRectanglesRequest?
    private var consecutiveMissedFrames = 0
    private let maxMissedFramesBeforeLost = 5

    // MARK: - Init
    private override init() {
        super.init()
        setupVisionRequest()
    }

    // MARK: - Session Lifecycle

    func start() {
        guard !isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.captureSession.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stop() {
        guard isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.lastFaceEvent = nil
            }
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        // Front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // Video output
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Set orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Vision

    private func setupVisionRequest() {
        faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self else { return }
            if let error {
                print("[FaceDetection] Vision error: \(error)")
                return
            }
            self.handleVisionResults(request.results as? [VNFaceObservation])
        }
        faceRequest?.revision = VNDetectFaceRectanglesRequestRevision3
    }

    private func handleVisionResults(_ observations: [VNFaceObservation]?) {
        guard let observations, !observations.isEmpty else {
            consecutiveMissedFrames += 1
            if consecutiveMissedFrames >= maxMissedFramesBeforeLost {
                consecutiveMissedFrames = 0
                DispatchQueue.main.async { [weak self] in
                    self?.lastFaceEvent = nil
                    self?.faceLostPublisher.send()
                }
            }
            return
        }

        consecutiveMissedFrames = 0

        // Use the largest (closest) face
        guard let face = observations.max(by: { $0.boundingBox.area < $1.boundingBox.area }) else { return }

        let box = face.boundingBox
        // Vision coordinates: origin at bottom-left, flip Y for UIKit
        let center = CGPoint(x: box.midX, y: 1.0 - box.midY)
        let proximityRatio = Double(min(box.area * 4.0, 1.0)) // normalize area to 0-1
        let horizontalOffset = Double((box.midX - 0.5) * 2.0).clamped(to: -1.0...1.0)

        let event = FaceEvent(
            normalizedCenter: center,
            proximityRatio: proximityRatio,
            horizontalOffset: horizontalOffset,
            boundingBox: box
        )

        DispatchQueue.main.async { [weak self] in
            self?.lastFaceEvent = event
            self?.faceDetectedPublisher.send(event)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FaceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Throttle processing
        let now = CACurrentMediaTime()
        guard now - lastProcessedTime >= processingInterval else { return }
        lastProcessedTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = faceRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .up,
                                            options: [:])
        try? handler.perform([request])
    }
}

// MARK: - CGRect Helper

private extension CGRect {
    var area: CGFloat { width * height }
}
