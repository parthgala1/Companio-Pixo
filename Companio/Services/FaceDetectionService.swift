import Foundation
import AVFoundation
import Vision
import Combine
import CoreImage
import UIKit

// MARK: - FaceEvent

struct FaceEvent {
    let boundingBox: CGRect
    let normalizedCenter: CGPoint
    let proximityRatio: Double
    let horizontalOffset: Double
    let smileProbability: Double?
    let leftEyeClosed: Bool?
    let rightEyeClosed: Bool?
    let yaw: Double?
    let roll: Double?

    init(boundingBox: CGRect,
         normalizedCenter: CGPoint,
         proximityRatio: Double,
         horizontalOffset: Double,
         smileProbability: Double? = nil,
         leftEyeClosed: Bool? = nil,
         rightEyeClosed: Bool? = nil,
         yaw: Double? = nil,
         roll: Double? = nil) {
        self.boundingBox = boundingBox
        self.normalizedCenter = normalizedCenter
        self.proximityRatio = proximityRatio
        self.horizontalOffset = horizontalOffset
        self.smileProbability = smileProbability
        self.leftEyeClosed = leftEyeClosed
        self.rightEyeClosed = rightEyeClosed
        self.yaw = yaw
        self.roll = roll
    }
}

// MARK: - FaceExpression

struct FaceExpression {
    var smile: Double = 0
    var leftEyeClosed: Bool = false
    var rightEyeClosed: Bool = false
    var yaw: Double = 0
    var roll: Double = 0

    var reactionLabel: String {
        if smile > 0.7 { return "😄 Big Smile!" }
        if smile > 0.4 { return "🙂 Smiling" }
        if leftEyeClosed && !rightEyeClosed { return "😉 Winking (L)" }
        if rightEyeClosed && !leftEyeClosed { return "😉 Winking (R)" }
        if leftEyeClosed && rightEyeClosed { return "😌 Eyes Closed" }
        if abs(yaw) > 0.3 { return "👀 Looking Away" }
        if abs(roll) > 0.25 { return "🤔 Head Tilt" }
        return "😐 Neutral"
    }
}

// MARK: - FaceDetectionService

final class FaceDetectionService: NSObject, ObservableObject {

    static let shared = FaceDetectionService()

    // MARK: - Publishers
    let faceDetectedPublisher = PassthroughSubject<FaceEvent, Never>()
    let faceLostPublisher = PassthroughSubject<Void, Never>()

    // MARK: - Published
    @Published private(set) var currentExpression = FaceExpression()
    @Published private(set) var uiFaceBoundingBox: CGRect = .zero
    @Published private(set) var lastFaceEvent: FaceEvent?

    // MARK: - Camera Access
    var captureSessionForPreview: AVCaptureSession { _captureSession }

    // MARK: - Private
    private let _captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.companio.facedetection", qos: .userInteractive)
    private var lastProcessTime: CFAbsoluteTime = 0
    private let minProcessInterval: CFTimeInterval = 0.1
    private var isFaceCurrentlyDetected = false
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait

    // Vision requests
    private var faceRectRequest: VNDetectFaceRectanglesRequest!
    private var faceLandmarksRequest: VNDetectFaceLandmarksRequest!

    // MARK: - Init

    private override init() {
        super.init()
        setupVisionRequests()
        configureSession()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        DispatchQueue.main.async {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
    }

    // MARK: - Orientation Tracking

    @objc private func deviceOrientationChanged() {
        let orientation = UIDevice.current.orientation
        if orientation.isValidInterfaceOrientation {
            currentDeviceOrientation = orientation
        }
    }

    /// Maps device orientation to CGImagePropertyOrientation for the front camera
    /// with `isVideoMirrored = true` on the capture connection.
    private func visionOrientation() -> CGImagePropertyOrientation {
        switch currentDeviceOrientation {
        case .portrait:            return .leftMirrored
        case .portraitUpsideDown:  return .rightMirrored
        case .landscapeLeft:       return .downMirrored
        case .landscapeRight:      return .upMirrored
        default:                   return .leftMirrored
        }
    }

    // MARK: - Lifecycle

    func start() {
        processingQueue.async { [weak self] in
            self?._captureSession.startRunning()
        }
    }

    func stop() {
        processingQueue.async { [weak self] in
            self?._captureSession.stopRunning()
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        _captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }

        if _captureSession.canAddInput(input) {
            _captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if _captureSession.canAddOutput(videoOutput) {
            _captureSession.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }
    }

    // MARK: - Vision Setup

    private func setupVisionRequests() {
        faceRectRequest = VNDetectFaceRectanglesRequest()
        faceLandmarksRequest = VNDetectFaceLandmarksRequest()
    }

    // MARK: - Vision Processing

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessTime >= minProcessInterval else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: visionOrientation(), options: [:])

        do {
            try handler.perform([faceRectRequest, faceLandmarksRequest])
            handleVisionResults()
        } catch {
            // Silently discard
        }
    }

    private func handleVisionResults() {
        guard let faceObs = faceRectRequest.results?.first else {
            if isFaceCurrentlyDetected {
                isFaceCurrentlyDetected = false
                DispatchQueue.main.async { [weak self] in
                    self?.faceLostPublisher.send()
                    self?.uiFaceBoundingBox = .zero
                    self?.lastFaceEvent = nil
                }
            }
            return
        }

        isFaceCurrentlyDetected = true

        let bb = faceObs.boundingBox
        let center = CGPoint(x: bb.midX, y: bb.midY)
        let proximity = Double(bb.width * bb.height)
        let hOffset = Double(center.x - 0.5) * 2.0

        let yawValue = faceObs.yaw?.doubleValue ?? 0
        let rollValue = faceObs.roll?.doubleValue ?? 0

        var smileProb: Double? = nil
        var leftEyeIsClosed: Bool? = nil
        var rightEyeIsClosed: Bool? = nil

        if let landmarkObs = faceLandmarksRequest.results?.first,
           let landmarks = landmarkObs.landmarks {

            // Smile estimation from outer lips
            if let outerLips = landmarks.outerLips {
                let points = outerLips.normalizedPoints
                if points.count >= 6 {
                    var minX: CGFloat = 1, maxX: CGFloat = 0
                    var minY: CGFloat = 1, maxY: CGFloat = 0
                    for p in points {
                        if p.x < minX { minX = p.x }
                        if p.x > maxX { maxX = p.x }
                        if p.y < minY { minY = p.y }
                        if p.y > maxY { maxY = p.y }
                    }
                    let lipWidth = maxX - minX
                    let lipHeight = max(maxY - minY, 0.001)
                    let ratio = lipWidth / lipHeight
                    let normalized = (Double(ratio) - 1.5) / 1.5
                    smileProb = min(max(normalized, 0), 1)
                }
            }

            // Left eye closure
            if let leftEye = landmarks.leftEye {
                let pts = leftEye.normalizedPoints
                if pts.count >= 4 {
                    var minY: CGFloat = 1, maxY: CGFloat = 0
                    for p in pts {
                        if p.y < minY { minY = p.y }
                        if p.y > maxY { maxY = p.y }
                    }
                    leftEyeIsClosed = (maxY - minY) < 0.025
                }
            }

            // Right eye closure
            if let rightEye = landmarks.rightEye {
                let pts = rightEye.normalizedPoints
                if pts.count >= 4 {
                    var minY: CGFloat = 1, maxY: CGFloat = 0
                    for p in pts {
                        if p.y < minY { minY = p.y }
                        if p.y > maxY { maxY = p.y }
                    }
                    rightEyeIsClosed = (maxY - minY) < 0.025
                }
            }
        }

        let event = FaceEvent(
            boundingBox: bb,
            normalizedCenter: center,
            proximityRatio: proximity,
            horizontalOffset: hOffset,
            smileProbability: smileProb,
            leftEyeClosed: leftEyeIsClosed,
            rightEyeClosed: rightEyeIsClosed,
            yaw: yawValue,
            roll: rollValue
        )

        let expression = FaceExpression(
            smile: smileProb ?? 0,
            leftEyeClosed: leftEyeIsClosed ?? false,
            rightEyeClosed: rightEyeIsClosed ?? false,
            yaw: yawValue,
            roll: rollValue
        )

        // Flip bounding box Y for UIKit coordinates
        let uiBox = CGRect(
            x: bb.origin.x,
            y: 1.0 - bb.origin.y - bb.height,
            width: bb.width,
            height: bb.height
        )

        DispatchQueue.main.async { [weak self] in
            self?.faceDetectedPublisher.send(event)
            self?.currentExpression = expression
            self?.uiFaceBoundingBox = uiBox
            self?.lastFaceEvent = event
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FaceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        processFrame(sampleBuffer)
    }
}
