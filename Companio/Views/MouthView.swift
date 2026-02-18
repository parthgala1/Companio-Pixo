import SwiftUI

// MARK: - MouthState

/// All possible mouth expressions. Drives Bezier path morphing.
enum MouthState: Equatable {
    case neutral
    case smile
    case frown
    case bored          // Flat line
    case surprise       // Small "o"
    case laugh          // Wide open, high curvature
    case open           // Talking — medium open
    case talking(level: CGFloat)  // Amplitude-driven during speech
    case wavySmile      // Sinusoidal smile (singing)
    case wavyFrown      // Sinusoidal frown (sad/crying)
}

// MARK: - MouthView

/// Morphable mouth using Canvas + animated @State parameters.
/// State changes drive smooth interpolation — Canvas redraws each animation frame.
struct MouthView: View {
    var state: MouthState = .neutral
    var eyeColor: Color = .cyan     // Tints the mouth to match eye identity
    var width: CGFloat = 80

    // MARK: - Animated Drawing Parameters
    // Canvas reads these @State values, which SwiftUI interpolates during animations.
    @State private var animOpenness: CGFloat = 0.0
    @State private var animCurvature: CGFloat = 0.15
    @State private var animSurprise: CGFloat = 0.0
    @State private var animBored: CGFloat = 0.0
    @State private var animWavy: CGFloat = 0.0

    // MARK: - Target Values (derived from state)
    private var targetOpenness: CGFloat {
        switch state {
        case .neutral:          return 0.0
        case .smile:            return 0.0
        case .frown:            return 0.0
        case .bored:            return 0.0
        case .surprise:         return 0.55
        case .laugh:            return 0.85
        case .open:             return 0.45
        case .talking(let l):   return max(0.05, l)
        case .wavySmile:        return 0.0
        case .wavyFrown:        return 0.0
        }
    }

    private var targetCurvature: CGFloat {
        switch state {
        case .neutral:          return 0.15
        case .smile:            return 0.85
        case .frown:            return -0.7
        case .bored:            return 0.0
        case .surprise:         return 0.0
        case .laugh:            return 0.9
        case .open:             return 0.3
        case .talking(let l):   return 0.2 + l * 0.1
        case .wavySmile:        return 0.6
        case .wavyFrown:        return -0.5
        }
    }

    private var targetSurprise: CGFloat {
        if case .surprise = state { return 1.0 }
        return 0.0
    }

    private var targetBored: CGFloat {
        if case .bored = state { return 1.0 }
        return 0.0
    }

    private var targetWavy: CGFloat {
        switch state {
        case .wavySmile, .wavyFrown: return 1.0
        default: return 0.0
        }
    }

    private var height: CGFloat { width * 0.38 }

    var body: some View {
        Canvas { context, size in
            drawMouth(context: context, size: size)
        }
        .frame(width: width, height: height)
        .onChange(of: state) { _, _ in
            animateToTargets()
        }
        .onAppear {
            // Snap to initial state without animation
            animOpenness = targetOpenness
            animCurvature = targetCurvature
            animSurprise = targetSurprise
            animBored = targetBored
            animWavy = targetWavy
        }
    }

    // MARK: - Animation Driver

    /// Determines the appropriate animation curve and duration for a state change,
    /// then smoothly interpolates all drawing parameters to their new targets.
    private func animateToTargets() {
        let animation: Animation
        switch state {
        case .talking:
            animation = .linear(duration: 0.06)
        case .surprise, .bored:
            animation = .easeInOut(duration: 0.25)
        default:
            animation = .spring(response: 0.35, dampingFraction: 0.75)
        }
        withAnimation(animation) {
            animOpenness = targetOpenness
            animCurvature = targetCurvature
            animSurprise = targetSurprise
            animBored = targetBored
            animWavy = targetWavy
        }
    }

    // MARK: - Canvas Drawing

    /// Draws the mouth using animated parameters. Uses crossfade blending
    /// between surprise/bored overlays and the base mouth shape.
    private func drawMouth(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let midX = w / 2
        let midY = h / 2

        // Wavy mouth — crossfades in for singing/sad emotes
        if animWavy > 0.01 {
            var ctx = context
            ctx.opacity = Double(min(animWavy, 1.0))
            drawWavyMouth(context: ctx, w: w, h: h, midX: midX, midY: midY)
            return  // wavy replaces all other mouth shapes
        }

        // Base mouth (closed line or open shape) — fades out during surprise/bored
        let baseFactor = max(0.0, 1.0 - animSurprise - animBored)
        if baseFactor > 0.01 {
            var ctx = context
            ctx.opacity = Double(baseFactor)
            drawBaseMouth(context: ctx, w: w, h: h, midX: midX, midY: midY)
        }

        // Surprise "o" — crossfades in
        if animSurprise > 0.01 {
            var ctx = context
            ctx.opacity = Double(min(animSurprise, 1.0))
            drawSurprise(context: ctx, w: w, h: h, midX: midX, midY: midY)
        }

        // Bored flat line — crossfades in
        if animBored > 0.01 {
            var ctx = context
            ctx.opacity = Double(min(animBored, 1.0))
            drawBored(context: ctx, w: w, h: h, midX: midX, midY: midY)
        }
    }

    private func drawBaseMouth(context: GraphicsContext, w: CGFloat, h: CGFloat, midX: CGFloat, midY: CGFloat) {
        if animOpenness < 0.05 {
            // Closed mouth: curved line
            let curveDepth = animCurvature * h * 0.55
            var path = Path()
            path.move(to: CGPoint(x: midX - w * 0.38, y: midY))
            path.addQuadCurve(
                to: CGPoint(x: midX + w * 0.38, y: midY),
                control: CGPoint(x: midX, y: midY + curveDepth)
            )
            context.stroke(path, with: .color(eyeColor.opacity(0.88)),
                           style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        } else {
            // Open mouth: filled shape
            let curveDepth = animCurvature * h * 0.5
            let openH = animOpenness * h * 0.82

            var path = Path()
            // Top lip
            path.move(to: CGPoint(x: midX - w * 0.38, y: midY - openH * 0.28))
            path.addQuadCurve(
                to: CGPoint(x: midX + w * 0.38, y: midY - openH * 0.28),
                control: CGPoint(x: midX, y: midY - openH * 0.28 - curveDepth * 0.25)
            )
            // Right corner
            path.addLine(to: CGPoint(x: midX + w * 0.33, y: midY + openH * 0.52))
            // Bottom lip
            path.addQuadCurve(
                to: CGPoint(x: midX - w * 0.33, y: midY + openH * 0.52),
                control: CGPoint(x: midX, y: midY + openH * 0.52 + curveDepth * 0.5)
            )
            path.closeSubpath()

            // Interior
            context.fill(path, with: .color(Color.black.opacity(0.72)))
            // Lip outline
            context.stroke(path, with: .color(eyeColor.opacity(0.82)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawSurprise(context: GraphicsContext, w: CGFloat, h: CGFloat, midX: CGFloat, midY: CGFloat) {
        let scale = min(animSurprise, 1.0)
        let ow = w * 0.28 * scale
        let oh = h * 0.72 * scale
        guard ow > 1 && oh > 1 else { return }
        let rect = CGRect(x: midX - ow / 2, y: midY - oh / 2, width: ow, height: oh)
        let path = Path(ellipseIn: rect)
        context.fill(path, with: .color(Color.black.opacity(0.7)))
        context.stroke(path, with: .color(eyeColor.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func drawBored(context: GraphicsContext, w: CGFloat, h: CGFloat, midX: CGFloat, midY: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: midX - w * 0.28, y: midY))
        path.addLine(to: CGPoint(x: midX + w * 0.28, y: midY))
        context.stroke(path, with: .color(eyeColor.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    /// Draws a sinusoidal wavy curve. Curvature determines if smile (>0) or frown (<0).
    private func drawWavyMouth(context: GraphicsContext, w: CGFloat, h: CGFloat, midX: CGFloat, midY: CGFloat) {
        let curveDir = animCurvature  // positive = smile, negative = frown
        let amplitude = h * 0.12
        let halfWidth = w * 0.38
        let segments = 3  // number of waves
        let segWidth = (halfWidth * 2) / CGFloat(segments)
        let baseY = midY + curveDir * h * 0.15

        var path = Path()
        path.move(to: CGPoint(x: midX - halfWidth, y: baseY))

        for i in 0..<segments {
            let startX = midX - halfWidth + CGFloat(i) * segWidth
            let endX = startX + segWidth
            let cpY = (i % 2 == 0) ? baseY - amplitude : baseY + amplitude
            path.addQuadCurve(
                to: CGPoint(x: endX, y: baseY),
                control: CGPoint(x: (startX + endX) / 2, y: cpY)
            )
        }

        context.stroke(path, with: .color(eyeColor.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 28) {
            MouthView(state: .smile, eyeColor: .cyan)
            MouthView(state: .talking(level: 0.6), eyeColor: .cyan)
            MouthView(state: .frown, eyeColor: .cyan)
            MouthView(state: .surprise, eyeColor: .cyan)
            MouthView(state: .bored, eyeColor: .cyan)
            MouthView(state: .laugh, eyeColor: .cyan)
        }
    }
}
