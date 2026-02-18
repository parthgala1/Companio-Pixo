import SwiftUI

// MARK: - HandMood

/// What emotion/mode is driving the hands to appear.
enum HandMood: Equatable {
    case dance
    case shy
    case celebrate
    case embarrass
    case copy
}

// MARK: - HandsView

/// Minimal floating hands — appear only during specific modes.
/// Same color as eyes, slightly darker. Never static when visible.
struct HandsView: View {
    var mood: HandMood
    var eyeColor: Color
    var isLandscape: Bool = false

    @State private var wiggle: Bool = false
    @State private var floatPhase: Double = 0

    // Hand shape: small rounded rectangle
    private let handWidth: CGFloat = 28
    private let handHeight: CGFloat = 38

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let handColor = eyeColor.opacity(0.75)

            ZStack {
                // Left hand
                handShape(color: handColor)
                    .offset(leftHandOffset(w: w, h: h))
                    .rotationEffect(leftHandRotation)
                    .scaleEffect(wiggle ? 1.08 : 0.95)

                // Right hand
                handShape(color: handColor)
                    .offset(rightHandOffset(w: w, h: h))
                    .rotationEffect(rightHandRotation)
                    .scaleEffect(wiggle ? 0.95 : 1.08)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: moodWiggleSpeed).repeatForever(autoreverses: true)) {
                wiggle = true
            }
        }
        .onDisappear {
            wiggle = false
        }
    }

    // MARK: - Hand Shape

    private func handShape(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color)
            .frame(width: handWidth, height: handHeight)
            .shadow(color: eyeColor.opacity(0.4), radius: 8)
    }

    // MARK: - Position Logic

    private func leftHandOffset(w: CGFloat, h: CGFloat) -> CGSize {
        switch mood {
        case .dance:
            return CGSize(width: -w * 0.32, height: h * 0.08)
        case .shy:
            // Hands covering face — close to center, high up
            return CGSize(width: -w * 0.18, height: -h * 0.05)
        case .celebrate:
            return CGSize(width: -w * 0.30, height: -h * 0.12)
        case .embarrass:
            return CGSize(width: -w * 0.20, height: h * 0.02)
        case .copy:
            return CGSize(width: -w * 0.28, height: h * 0.05)
        }
    }

    private func rightHandOffset(w: CGFloat, h: CGFloat) -> CGSize {
        switch mood {
        case .dance:
            return CGSize(width: w * 0.32, height: h * 0.08)
        case .shy:
            return CGSize(width: w * 0.18, height: -h * 0.05)
        case .celebrate:
            return CGSize(width: w * 0.30, height: -h * 0.12)
        case .embarrass:
            return CGSize(width: w * 0.20, height: h * 0.02)
        case .copy:
            return CGSize(width: w * 0.28, height: h * 0.05)
        }
    }

    private var leftHandRotation: Angle {
        switch mood {
        case .dance:      return .degrees(wiggle ? -25 : -15)
        case .shy:        return .degrees(-10)
        case .celebrate:  return .degrees(wiggle ? -40 : -20)
        case .embarrass:  return .degrees(15)
        case .copy:       return .degrees(-5)
        }
    }

    private var rightHandRotation: Angle {
        switch mood {
        case .dance:      return .degrees(wiggle ? 25 : 15)
        case .shy:        return .degrees(10)
        case .celebrate:  return .degrees(wiggle ? 40 : 20)
        case .embarrass:  return .degrees(-15)
        case .copy:       return .degrees(5)
        }
    }

    private var moodWiggleSpeed: Double {
        switch mood {
        case .dance:      return 0.25   // Fast
        case .celebrate:  return 0.3
        case .shy:        return 0.8    // Slow, nervous
        case .embarrass:  return 0.6
        case .copy:       return 0.5
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HandsView(mood: .dance, eyeColor: .cyan)
            .frame(width: 200, height: 200)
    }
}
