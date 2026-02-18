import SwiftUI

// MARK: - CompanionView

/// Full-screen presence. Black background, ambient glow, face. Nothing else.
struct CompanionView: View {
    @EnvironmentObject var companionVM: CompanionViewModel
    @EnvironmentObject var speechVM: SpeechViewModel

    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // Pure black
            Color.black.ignoresSafeArea()

            // Ambient glow — breathes slowly behind the face
            ambientGlow

            // The face
            CompanionFaceView()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        let isDance = speechVM.playModeVM.activeMode == .dance
        let isSilent = speechVM.playModeVM.activeMode == .silentCompanion

        let intensity = companionVM.glowIntensity
        let glowRadius: CGFloat = isDance ? 220 : 160
        let opacityHigh: Double = (isSilent ? 0.06 : (isDance ? 0.35 : 0.18)) * intensity
        let opacityLow: Double = (isSilent ? 0.02 : (isDance ? 0.12 : 0.06)) * intensity
        let glowSpeed: Double = isSilent ? 4.5 : (isDance ? 0.5 : 2.5)

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        companionVM.eyeColor.opacity(glowPulse ? opacityHigh : opacityLow),
                        companionVM.eyeColor.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: glowRadius
                )
            )
            .frame(width: glowRadius * 2.2, height: glowRadius * 1.5)
            .blur(radius: 24)
            .animation(.easeInOut(duration: glowSpeed).repeatForever(autoreverses: true), value: glowPulse)
            .animation(.easeInOut(duration: 0.6), value: companionVM.eyeColor)
    }
}
