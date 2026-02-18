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
