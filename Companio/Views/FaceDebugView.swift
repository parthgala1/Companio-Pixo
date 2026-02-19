import SwiftUI
import AVFoundation

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let connection = previewLayer.connection,
                  connection.isVideoOrientationSupported else { return }
            switch UIDevice.current.orientation {
            case .portrait:            connection.videoOrientation = .portrait
            case .landscapeLeft:       connection.videoOrientation = .landscapeRight
            case .landscapeRight:      connection.videoOrientation = .landscapeLeft
            case .portraitUpsideDown:   connection.videoOrientation = .portraitUpsideDown
            default: break
            }
        }
    }
}

// MARK: - FaceDebugView

struct FaceDebugView: View {
    let accentColor: Color
    @ObservedObject private var faceService = FaceDetectionService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isLandscape ? 12 : 20) {
                        header
                        cameraContent(height: isLandscape ? max(geometry.size.height - 160, 180) : 400)
                        expressionCard
                        Spacer(minLength: 16)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Face Recognition")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Live Vision Analysis")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Camera Section

    private func cameraContent(height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                CameraPreviewView(session: faceService.captureSessionForPreview)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Bounding box overlay
                if faceService.uiFaceBoundingBox != .zero {
                    let box = faceService.uiFaceBoundingBox
                    let rect = CGRect(
                        x: box.origin.x * geo.size.width,
                        y: box.origin.y * geo.size.height,
                        width: box.width * geo.size.width,
                        height: box.height * geo.size.height
                    )

                    FaceBoundingBoxView(accentColor: accentColor)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    // Reaction label
                    Text(faceService.currentExpression.reactionLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(accentColor.opacity(0.7)))
                        .position(x: rect.midX, y: rect.minY - 16)
                }
            }
        }
        .frame(height: height)
        .padding(.horizontal, 20)
    }

    // MARK: - Expression Card

    private var expressionCard: some View {
        VStack(spacing: 12) {
            Text("Expression Metrics")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 16) {
                metricView(title: "Smile", value: String(format: "%.0f%%", faceService.currentExpression.smile * 100))
                metricView(title: "Yaw", value: String(format: "%.1f"+"°", faceService.currentExpression.yaw * 57.3))
                metricView(title: "Roll", value: String(format: "%.1f"+"°", faceService.currentExpression.roll * 57.3))
            }

            HStack(spacing: 16) {
                metricView(title: "L Eye", value: faceService.currentExpression.leftEyeClosed ? "Closed" : "Open")
                metricView(title: "R Eye", value: faceService.currentExpression.rightEyeClosed ? "Closed" : "Open")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Metric View

    private func metricView(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(accentColor)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Face Bounding Box

struct FaceBoundingBoxView: View {
    let accentColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.6), lineWidth: 2)

            // Corner brackets
            CornerBracket(corner: .topLeft, color: accentColor)
            CornerBracket(corner: .topRight, color: accentColor)
            CornerBracket(corner: .bottomLeft, color: accentColor)
            CornerBracket(corner: .bottomRight, color: accentColor)
        }
        .animation(.easeOut(duration: 0.15), value: accentColor)
    }
}

// MARK: - Corner Bracket

struct CornerBracket: View {
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

    let corner: Corner
    let color: Color
    private let armLength: CGFloat = 16
    private let thickness: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: 0, y: armLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: armLength, y: 0))
                case .topRight:
                    path.move(to: CGPoint(x: w - armLength, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: armLength))
                case .bottomLeft:
                    path.move(to: CGPoint(x: 0, y: h - armLength))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: armLength, y: h))
                case .bottomRight:
                    path.move(to: CGPoint(x: w - armLength, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - armLength))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        }
    }
}
