import SwiftUI

// MARK: - CompanionFaceView

/// The complete face: two eyes, one mouth, optional hands, and emote overlays.
/// Uses GeometryReader for proportional layout in both orientations.
/// Replaces ExpressionView.
struct CompanionFaceView: View {
    @EnvironmentObject var companionVM: CompanionViewModel
    @EnvironmentObject var speechVM: SpeechViewModel

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let faceWidth = isLandscape ? geo.size.height * 0.55 : geo.size.width * 0.65
            let eyeSize = faceWidth * 0.38
            let eyeSpacing = isLandscape ? faceWidth * 0.58 : faceWidth * 0.52
            let mouthWidth = faceWidth * 0.62
            let faceVerticalOffset = isLandscape ? 0.0 : -geo.size.height * 0.04

            let activeEmote = companionVM.activeEmote
            let showsFace = activeEmote?.showsFace ?? true
            let hidesBrows = activeEmote?.hidesBrows ?? false
            let leftStyle = activeEmote?.leftEyeStyle ?? .normal
            let rightStyle = activeEmote?.rightEyeStyle ?? .normal

            ZStack {
                // Hands (behind face)
                if let handMood = companionVM.handMood {
                    HandsView(mood: handMood, eyeColor: companionVM.eyeColor, isLandscape: isLandscape)
                        .frame(width: faceWidth * 1.6, height: faceWidth * 1.2)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + faceWidth * 0.1)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .scale(scale: 0.5).combined(with: .opacity)
                        ))
                }

                // Face group — eyes + mouth (hidden in love mode)
                if showsFace {
                    VStack(spacing: isLandscape ? eyeSize * 0.55 : eyeSize * 0.65) {
                        // Eyes row
                        HStack(spacing: eyeSpacing) {
                            EyeView(
                                blinkProgress: companionVM.leftEyeBlinkProgress,
                                pupilOffset: companionVM.pupilOffset,
                                pupilScale: companionVM.pupilScale,
                                eyeColor: companionVM.eyeColor,
                                eyeSize: eyeSize,
                                browTilt: companionVM.browTilt,
                                style: leftStyle,
                                hideBrow: hidesBrows
                            )

                            EyeView(
                                blinkProgress: companionVM.rightEyeBlinkProgress,
                                pupilOffset: CGPoint(
                                    x: -companionVM.pupilOffset.x,
                                    y: companionVM.pupilOffset.y
                                ),
                                pupilScale: companionVM.pupilScale,
                                eyeColor: companionVM.eyeColor,
                                eyeSize: eyeSize,
                                browTilt: -companionVM.browTilt,  // mirrored for symmetry
                                style: rightStyle,
                                hideBrow: hidesBrows
                            )
                        }

                        // Mouth
                        MouthView(
                            state: companionVM.mouthState,
                            eyeColor: companionVM.eyeColor,
                            width: mouthWidth
                        )
                    }
                    .offset(
                        x: companionVM.angerShakeOffset,
                        y: companionVM.idleFloatOffset + faceVerticalOffset
                    )
                    .scaleEffect(faceScale * companionVM.touchScale * (companionVM.smallEyesActive ? 0.88 : 1.0))
                    .rotationEffect(.degrees(companionVM.faceTiltAngle))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Emote overlays (?, thumbs up, music notes, ZZZ, HA, tears, heart, battery)
                if let emote = activeEmote, !emote.overlayElements.isEmpty {
                    EmoteOverlayView(
                        elements: emote.overlayElements,
                        eyeColor: companionVM.eyeColor,
                        faceWidth: faceWidth
                    )
                    .offset(y: companionVM.idleFloatOffset + faceVerticalOffset)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }

                // Overlay stack — ephemeral staggered overlays (petting, anger, etc.)
                if !companionVM.activeOverlays.isEmpty {
                    ForEach(companionVM.activeOverlays) { overlay in
                        EmoteOverlayView(
                            elements: [overlay.type],
                            eyeColor: companionVM.eyeColor,
                            faceWidth: faceWidth
                        )
                        .offset(y: companionVM.idleFloatOffset + faceVerticalOffset)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: companionVM.handMood)
            .animation(.easeInOut(duration: 0.4), value: activeEmote?.id)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: companionVM.activeOverlays.count)
            .animation(.easeInOut(duration: 0.5), value: isLandscape)
        }
    }

    private var faceScale: CGFloat {
        let arousalBoost = companionVM.arousalScale
        return 1.0 + CGFloat(arousalBoost) * 0.06
    }
}
