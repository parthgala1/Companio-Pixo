import SwiftUI

// MARK: - EmoteOverlayView

/// Renders decorative overlay elements (?, thumbs up, music notes, ZZZ, HA, tears, heart, battery)
/// positioned relative to the companion face.
struct EmoteOverlayView: View {
    let elements: [EmoteOverlayElement]
    let eyeColor: Color
    let faceWidth: CGFloat

    @State private var animatePhase: Bool = false

    var body: some View {
        ZStack {
            ForEach(Array(elements.enumerated()), id: \.element) { _, element in
                overlayContent(for: element)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animatePhase = true
            }
        }
    }

    // MARK: - Element Router

    @ViewBuilder
    private func overlayContent(for element: EmoteOverlayElement) -> some View {
        switch element {
        case .questionMark:
            questionMarkView
        case .thumbsUp:
            thumbsUpView
        case .tears:
            tearsView
        case .musicNotes:
            musicNotesView
        case .lowBattery:
            lowBatteryView
        case .haText:
            haTextView
        case .zzz:
            zzzView
        case .heart:
            heartView
        case .sparkle:
            sparkleView
        case .tinyHeartsFloat:
            tinyHeartsFloatView
        case .blushWide:
            blushWideView
        case .loveAura:
            loveAuraView
        case .happyBounceLines:
            happyBounceLinesView
        case .softHalo:
            softHaloView
        case .angerPulse:
            angerPulseView
        case .hummingNote:
            hummingNoteView
        case .chargingBattery:
            chargingBatteryView
        }
    }

    // MARK: - Question Mark

    private var questionMarkView: some View {
        Text("?")
            .font(.system(size: faceWidth * 0.22, weight: .bold, design: .rounded))
            .foregroundColor(eyeColor)
            .shadow(color: eyeColor.opacity(0.7), radius: 8)
            .shadow(color: eyeColor.opacity(0.3), radius: 16)
            .offset(x: faceWidth * 0.38, y: faceWidth * 0.05)
            .scaleEffect(animatePhase ? 1.05 : 0.95)
    }

    // MARK: - Thumbs Up

    private var thumbsUpView: some View {
        ThumbsUpShape()
            .fill(eyeColor)
            .frame(width: faceWidth * 0.2, height: faceWidth * 0.28)
            .shadow(color: eyeColor.opacity(0.6), radius: 10)
            .shadow(color: eyeColor.opacity(0.25), radius: 20)
            .offset(x: faceWidth * 0.52, y: -faceWidth * 0.05)
            .scaleEffect(animatePhase ? 1.08 : 0.96)
    }

    // MARK: - Tears

    private var tearsView: some View {
        HStack(spacing: faceWidth * 0.55) {
            tearDrop
                .offset(y: animatePhase ? faceWidth * 0.12 : faceWidth * 0.04)
            tearDrop
                .offset(y: animatePhase ? faceWidth * 0.08 : faceWidth * 0.0)
        }
        .offset(y: faceWidth * 0.12)
    }

    private var tearDrop: some View {
        Ellipse()
            .fill(eyeColor.opacity(0.7))
            .frame(width: faceWidth * 0.06, height: faceWidth * 0.1)
            .shadow(color: eyeColor.opacity(0.4), radius: 4)
    }

    // MARK: - Music Notes

    private var musicNotesView: some View {
        ZStack {
            // Note 1 — upper left
            MusicNoteShape()
                .fill(eyeColor.opacity(0.8))
                .frame(width: faceWidth * 0.08, height: faceWidth * 0.14)
                .shadow(color: eyeColor.opacity(0.5), radius: 6)
                .offset(x: -faceWidth * 0.42, y: -faceWidth * 0.32)
                .scaleEffect(animatePhase ? 1.1 : 0.9)
                .rotationEffect(.degrees(animatePhase ? -10 : 10))

            // Note 2 — upper right
            MusicNoteShape()
                .fill(eyeColor.opacity(0.7))
                .frame(width: faceWidth * 0.07, height: faceWidth * 0.12)
                .shadow(color: eyeColor.opacity(0.4), radius: 5)
                .offset(x: faceWidth * 0.45, y: -faceWidth * 0.38)
                .scaleEffect(animatePhase ? 0.9 : 1.1)
                .rotationEffect(.degrees(animatePhase ? 12 : -8))

            // Note 3 — mid left
            MusicNoteShape()
                .fill(eyeColor.opacity(0.6))
                .frame(width: faceWidth * 0.06, height: faceWidth * 0.1)
                .shadow(color: eyeColor.opacity(0.3), radius: 4)
                .offset(x: -faceWidth * 0.5, y: -faceWidth * 0.1)
                .scaleEffect(animatePhase ? 1.05 : 0.95)
                .rotationEffect(.degrees(animatePhase ? 5 : -12))
        }
    }

    // MARK: - Low Battery

    private var lowBatteryView: some View {
        ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.red.opacity(0.9), lineWidth: 2)
                .frame(width: faceWidth * 0.14, height: faceWidth * 0.08)

            // Battery cap
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.red.opacity(0.7))
                .frame(width: faceWidth * 0.02, height: faceWidth * 0.04)
                .offset(x: faceWidth * 0.08)

            // Low fill
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.red)
                .frame(width: faceWidth * 0.04, height: faceWidth * 0.05)
                .offset(x: -faceWidth * 0.035)
                .opacity(animatePhase ? 1.0 : 0.3)
        }
        .shadow(color: Color.red.opacity(0.5), radius: 6)
        .offset(x: -faceWidth * 0.38, y: faceWidth * 0.48)
    }

    // MARK: - HA Text

    private var haTextView: some View {
        Text("HA")
            .font(.system(size: faceWidth * 0.14, weight: .heavy, design: .rounded))
            .foregroundColor(eyeColor)
            .shadow(color: eyeColor.opacity(0.6), radius: 8)
            .shadow(color: eyeColor.opacity(0.3), radius: 14)
            .offset(x: faceWidth * 0.34, y: faceWidth * 0.2)
            .scaleEffect(animatePhase ? 1.1 : 0.92)
            .rotationEffect(.degrees(animatePhase ? 3 : -3))
    }

    // MARK: - ZZZ

    private var zzzView: some View {
        VStack(alignment: .trailing, spacing: faceWidth * 0.01) {
            Text("Z")
                .font(.system(size: faceWidth * 0.08, weight: .bold, design: .rounded))
            Text("Z")
                .font(.system(size: faceWidth * 0.11, weight: .bold, design: .rounded))
            Text("Z")
                .font(.system(size: faceWidth * 0.15, weight: .bold, design: .rounded))
        }
        .foregroundColor(eyeColor.opacity(0.8))
        .shadow(color: eyeColor.opacity(0.5), radius: 8)
        .offset(x: faceWidth * 0.35, y: -faceWidth * 0.35)
        .scaleEffect(animatePhase ? 1.08 : 0.94)
        .opacity(animatePhase ? 1.0 : 0.6)
    }

    // MARK: - Heart (Love Mode)

    private var heartView: some View {
        HeartShape()
            .fill(eyeColor)
            .frame(width: faceWidth * 0.8, height: faceWidth * 0.72)
            .shadow(color: eyeColor.opacity(0.7), radius: 20)
            .shadow(color: eyeColor.opacity(0.35), radius: 40)
            .scaleEffect(animatePhase ? 1.06 : 0.96)
    }

    // MARK: - Sparkle (Tiny Animated Stars)

    private var sparkleView: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i) * 72.0
                let radius = faceWidth * 0.42
                let x = cos(angle * .pi / 180) * radius
                let y = sin(angle * .pi / 180) * radius

                StarShape()
                    .fill(eyeColor.opacity(animatePhase ? 0.9 : 0.4))
                    .frame(width: faceWidth * 0.06, height: faceWidth * 0.06)
                    .offset(x: x, y: y)
                    .scaleEffect(animatePhase ? 1.2 : 0.6)
            }
        }
    }

    // MARK: - Tiny Hearts Float

    private var tinyHeartsFloatView: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let xOffset = CGFloat(i - 1) * faceWidth * 0.2

                HeartShape()
                    .fill(eyeColor.opacity(0.7 - Double(i) * 0.15))
                    .frame(width: faceWidth * 0.1, height: faceWidth * 0.09)
                    .offset(
                        x: xOffset,
                        y: animatePhase
                            ? -faceWidth * (0.4 + CGFloat(i) * 0.08)
                            : -faceWidth * 0.2
                    )
                    .opacity(animatePhase ? 0.3 : 1.0)
            }
        }
    }

    // MARK: - Blush Wide (Pink Gradient Under Eyes)

    private var blushWideView: some View {
        HStack(spacing: faceWidth * 0.28) {
            blushSpot
            blushSpot
        }
        .offset(y: faceWidth * 0.08)
    }

    private var blushSpot: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.pink.opacity(0.35), Color.pink.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: faceWidth * 0.12
                )
            )
            .frame(width: faceWidth * 0.2, height: faceWidth * 0.1)
            .opacity(animatePhase ? 0.8 : 0.5)
    }

    // MARK: - Love Aura (Warm Radial Glow Ring)

    private var loveAuraView: some View {
        Circle()
            .stroke(eyeColor.opacity(animatePhase ? 0.25 : 0.1), lineWidth: faceWidth * 0.02)
            .frame(width: faceWidth * 1.1, height: faceWidth * 1.1)
            .shadow(color: eyeColor.opacity(0.2), radius: 20)
            .scaleEffect(animatePhase ? 1.08 : 0.95)
    }

    // MARK: - Happy Bounce Lines

    private var happyBounceLinesView: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) * 90.0 + 45.0
                let radius = faceWidth * 0.48
                let x = cos(angle * .pi / 180) * radius
                let y = sin(angle * .pi / 180) * radius

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(eyeColor.opacity(0.5))
                    .frame(width: faceWidth * 0.08, height: faceWidth * 0.03)
                    .rotationEffect(.degrees(angle))
                    .offset(x: x, y: y)
                    .scaleEffect(animatePhase ? 1.2 : 0.7)
                    .opacity(animatePhase ? 0.8 : 0.3)
            }
        }
    }

    // MARK: - Soft Halo

    private var softHaloView: some View {
        Ellipse()
            .stroke(eyeColor.opacity(animatePhase ? 0.3 : 0.12), lineWidth: faceWidth * 0.015)
            .frame(width: faceWidth * 0.6, height: faceWidth * 0.15)
            .shadow(color: eyeColor.opacity(0.2), radius: 8)
            .offset(y: -faceWidth * 0.55)
            .scaleEffect(animatePhase ? 1.05 : 0.98)
    }

    // MARK: - Anger Pulse (Cross Mark)

    private var angerPulseView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.red.opacity(0.8))
                .frame(width: faceWidth * 0.12, height: faceWidth * 0.03)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.red.opacity(0.8))
                .frame(width: faceWidth * 0.03, height: faceWidth * 0.12)
        }
        .rotationEffect(.degrees(45))
        .shadow(color: Color.red.opacity(0.5), radius: 6)
        .offset(x: faceWidth * 0.35, y: -faceWidth * 0.4)
        .scaleEffect(animatePhase ? 1.15 : 0.9)
        .opacity(animatePhase ? 1.0 : 0.6)
    }

    // MARK: - Humming Note

    private var hummingNoteView: some View {
        Text("~")
            .font(.system(size: faceWidth * 0.15, weight: .bold, design: .rounded))
            .foregroundColor(eyeColor.opacity(0.7))
            .shadow(color: eyeColor.opacity(0.4), radius: 6)
            .offset(x: faceWidth * 0.05, y: -faceWidth * 0.55)
            .scaleEffect(animatePhase ? 1.08 : 0.94)
    }

    // MARK: - Charging Battery

    private var chargingBatteryView: some View {
        ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.green.opacity(0.9), lineWidth: 2)
                .frame(width: faceWidth * 0.16, height: faceWidth * 0.09)

            // Battery cap
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.green.opacity(0.7))
                .frame(width: faceWidth * 0.02, height: faceWidth * 0.045)
                .offset(x: faceWidth * 0.09)

            // Animated fill — grows from left to right
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.9), Color.green.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: animatePhase ? faceWidth * 0.12 : faceWidth * 0.04,
                    height: faceWidth * 0.06
                )
                .offset(x: animatePhase ? 0 : -faceWidth * 0.035)

            // Lightning bolt
            LightningBoltShape()
                .fill(Color.yellow)
                .frame(width: faceWidth * 0.05, height: faceWidth * 0.07)
                .shadow(color: Color.yellow.opacity(0.6), radius: 4)
                .opacity(animatePhase ? 1.0 : 0.5)
        }
        .shadow(color: Color.green.opacity(0.5), radius: 8)
        .offset(x: -faceWidth * 0.38, y: faceWidth * 0.48)
        .scaleEffect(animatePhase ? 1.05 : 0.95)
    }
}

// MARK: - Custom Shapes

/// A simple music note shape (circle + stem + flag).
struct MusicNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let noteRadius = rect.width * 0.4
        let stemX = rect.midX + noteRadius * 0.6
        let noteY = rect.maxY - noteRadius

        // Note head
        path.addEllipse(in: CGRect(
            x: rect.midX - noteRadius,
            y: noteY - noteRadius * 0.6,
            width: noteRadius * 2,
            height: noteRadius * 1.2
        ))

        // Stem
        path.move(to: CGPoint(x: stemX, y: noteY - noteRadius * 0.2))
        path.addLine(to: CGPoint(x: stemX, y: rect.minY + rect.height * 0.1))

        // Flag
        path.addQuadCurve(
            to: CGPoint(x: stemX + rect.width * 0.2, y: rect.minY + rect.height * 0.35),
            control: CGPoint(x: stemX + rect.width * 0.35, y: rect.minY + rect.height * 0.1)
        )

        return path
    }
}

/// A heart shape for the love emote.
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midX = rect.midX

        path.move(to: CGPoint(x: midX, y: h * 0.25))

        // Left lobe
        path.addCurve(
            to: CGPoint(x: midX, y: h * 0.95),
            control1: CGPoint(x: -w * 0.1, y: -h * 0.15),
            control2: CGPoint(x: w * 0.05, y: h * 0.7)
        )

        // Right lobe
        path.addCurve(
            to: CGPoint(x: midX, y: h * 0.25),
            control1: CGPoint(x: w * 0.95, y: h * 0.7),
            control2: CGPoint(x: w * 1.1, y: -h * 0.15)
        )

        path.closeSubpath()
        return path
    }
}

/// A 4-pointed star shape for sparkle overlays.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 4

        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// A thumbs-up shape.
struct ThumbsUpShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Thumb
        path.move(to: CGPoint(x: w * 0.35, y: h * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.05),
            control: CGPoint(x: w * 0.25, y: h * 0.25)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.7, y: h * 0.45),
            control: CGPoint(x: w * 0.8, y: h * 0.08)
        )

        // Fist
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.9),
            control: CGPoint(x: w * 0.95, y: h * 0.7)
        )
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.9))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.55),
            control: CGPoint(x: w * 0.1, y: h * 0.75)
        )
        path.closeSubpath()

        // Finger lines
        path.move(to: CGPoint(x: w * 0.25, y: h * 0.65))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.65))

        path.move(to: CGPoint(x: w * 0.25, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.75))

        return path
    }
}

/// A lightning bolt shape for the charging battery overlay.
struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.55, y: 0))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.38, y: h))
        path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.42))
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 30) {
            EmoteOverlayView(elements: [.questionMark], eyeColor: .cyan, faceWidth: 200)
                .frame(width: 200, height: 200)
            EmoteOverlayView(elements: [.musicNotes], eyeColor: .cyan, faceWidth: 200)
                .frame(width: 200, height: 200)
            EmoteOverlayView(elements: [.heart], eyeColor: .cyan, faceWidth: 200)
                .frame(width: 200, height: 200)
        }
    }
}
