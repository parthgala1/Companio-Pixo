import SwiftUI

// MARK: - EyeView

/// A single eye with eyebrow, color, blink, ambient glow, and alternate style support.
/// Supports normal oval, round, spiral, wink, squint, and sleep-line styles via `EyeStyle`.
struct EyeView: View {
    var blinkProgress: Double      // 0.0 = open, 1.0 = fully closed
    var pupilOffset: CGPoint       // Normalized -1 to 1
    var pupilScale: Double         // 1.0 = normal, >1 = dilated
    var eyeColor: Color
    var eyeSize: CGFloat = 72

    // Eyebrow tilt: negative = raised outer (happy), positive = raised inner (concerned)
    var browTilt: Double = 0.0     // -1.0 to 1.0

    // Eye shape style — defaults to .normal (rounded rectangle)
    var style: EyeStyle = .normal

    // Whether to hide the eyebrow entirely
    var hideBrow: Bool = false

    // MARK: - Derived
    private var cornerRadius: CGFloat { eyeSize * 0.42 }
    private var blinkScaleY: CGFloat { CGFloat(max(0.04, 1.0 - blinkProgress * 0.97)) }

    // Eyebrow geometry
    private var browWidth: CGFloat { eyeSize * 0.82 }
    private var browThickness: CGFloat { eyeSize * 0.095 }
    private var browYOffset: CGFloat { -(eyeSize * 0.72) }  // above the eye
    private var browCornerRadius: CGFloat { browThickness * 0.5 }

    var body: some View {
        ZStack {
            // Eyebrow — sits above the eye body, hidden for certain emotes
            if !hideBrow && style != .hidden {
                eyebrow
            }

            // Eye body — style-dependent rendering
            eyeBody
        }
        .frame(width: eyeSize, height: eyeSize * 1.6)  // taller frame to include brow
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: eyeColor)
        .animation(.easeInOut(duration: 0.3), value: style)
    }

    // MARK: - Eye Body (Style-Based)

    @ViewBuilder
    private var eyeBody: some View {
        switch style {
        case .normal:
            normalEye
        case .round:
            roundEye
        case .spiral:
            spiralEye
        case .winkClosed:
            winkClosedEye
        case .happySquint:
            happySquintEye
        case .sleepLine:
            sleepLineEye
        case .hidden:
            EmptyView()
        }
    }

    // MARK: Normal Eye (rounded rect — original)

    private var normalEye: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(eyeColor)
            .frame(width: eyeSize, height: eyeSize)
            .scaleEffect(y: blinkScaleY, anchor: .center)
            .offset(
                x: pupilOffset.x * eyeSize * 0.15,
                y: pupilOffset.y * eyeSize * 0.15
            )
            .shadow(color: eyeColor.opacity(0.6), radius: 14, x: 0, y: 0)
            .shadow(color: eyeColor.opacity(0.25), radius: 30, x: 0, y: 0)
    }

    // MARK: Round Eye (circle — sad, shocked)

    private var roundEye: some View {
        Circle()
            .fill(eyeColor)
            .frame(width: eyeSize * 0.88, height: eyeSize * 0.88)
            .scaleEffect(y: blinkScaleY, anchor: .center)
            .offset(
                x: pupilOffset.x * eyeSize * 0.12,
                y: pupilOffset.y * eyeSize * 0.12
            )
            .shadow(color: eyeColor.opacity(0.6), radius: 14, x: 0, y: 0)
            .shadow(color: eyeColor.opacity(0.25), radius: 30, x: 0, y: 0)
    }

    // MARK: Spiral Eye (singing / low battery)

    private var spiralEye: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(eyeColor, lineWidth: eyeSize * 0.07)
                .frame(width: eyeSize * 0.8, height: eyeSize * 0.8)

            // Inner ring (spiral illusion)
            Circle()
                .stroke(eyeColor.opacity(0.8), lineWidth: eyeSize * 0.06)
                .frame(width: eyeSize * 0.45, height: eyeSize * 0.45)

            // Center dot
            Circle()
                .fill(eyeColor.opacity(0.7))
                .frame(width: eyeSize * 0.15, height: eyeSize * 0.15)
        }
        .shadow(color: eyeColor.opacity(0.5), radius: 10, x: 0, y: 0)
        .shadow(color: eyeColor.opacity(0.2), radius: 22, x: 0, y: 0)
    }

    // MARK: Wink Closed (curved arc ^)

    private var winkClosedEye: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midX = w / 2
            let midY = h / 2

            var path = Path()
            // Draw an upward arc (^) shape
            path.move(to: CGPoint(x: midX - w * 0.35, y: midY + h * 0.05))
            path.addQuadCurve(
                to: CGPoint(x: midX + w * 0.35, y: midY + h * 0.05),
                control: CGPoint(x: midX, y: midY - h * 0.25)
            )

            context.stroke(path, with: .color(eyeColor),
                           style: StrokeStyle(lineWidth: eyeSize * 0.08, lineCap: .round))
        }
        .frame(width: eyeSize, height: eyeSize)
        .shadow(color: eyeColor.opacity(0.5), radius: 10, x: 0, y: 0)
    }

    // MARK: Happy Squint (upward ∪ arcs — laughing)

    private var happySquintEye: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midX = w / 2
            let midY = h / 2

            var path = Path()
            // Upward bowing arc ∩ (inverted U)
            path.move(to: CGPoint(x: midX - w * 0.35, y: midY + h * 0.08))
            path.addQuadCurve(
                to: CGPoint(x: midX + w * 0.35, y: midY + h * 0.08),
                control: CGPoint(x: midX, y: midY - h * 0.22)
            )

            context.stroke(path, with: .color(eyeColor),
                           style: StrokeStyle(lineWidth: eyeSize * 0.09, lineCap: .round))
        }
        .frame(width: eyeSize, height: eyeSize)
        .shadow(color: eyeColor.opacity(0.5), radius: 10, x: 0, y: 0)
    }

    // MARK: Sleep Line (horizontal dash —)

    private var sleepLineEye: some View {
        RoundedRectangle(cornerRadius: eyeSize * 0.04, style: .continuous)
            .fill(eyeColor)
            .frame(width: eyeSize * 0.7, height: eyeSize * 0.1)
            .shadow(color: eyeColor.opacity(0.5), radius: 8, x: 0, y: 0)
            .shadow(color: eyeColor.opacity(0.2), radius: 18, x: 0, y: 0)
    }

    // MARK: - Eyebrow

    private var eyebrow: some View {
        let tiltAngle = Angle.degrees(Double(browTilt) * 18.0)

        return RoundedRectangle(cornerRadius: browCornerRadius, style: .continuous)
            .fill(eyeColor.opacity(0.9))
            .frame(width: browWidth, height: browThickness)
            .shadow(color: eyeColor.opacity(0.5), radius: 6, x: 0, y: 0)
            .rotationEffect(tiltAngle)
            .offset(y: browYOffset)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 40) {
            // Normal eyes
            HStack(spacing: 36) {
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, browTilt: 0.0)
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, browTilt: 0.0)
            }
            // Wink + normal
            HStack(spacing: 36) {
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, style: .winkClosed)
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan)
            }
            // Spiral eyes
            HStack(spacing: 36) {
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, style: .spiral)
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, style: .spiral)
            }
            // Happy squint + Sleep line
            HStack(spacing: 36) {
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, style: .happySquint)
                EyeView(blinkProgress: 0.0, pupilOffset: .zero, pupilScale: 1.0, eyeColor: .cyan, style: .sleepLine)
            }
        }
    }
}
