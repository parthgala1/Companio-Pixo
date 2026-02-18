import SwiftUI

// MARK: - RootView

/// The entire app UI. Just the face + one settings button.
/// Tap anywhere → listen. Long press → settings.
struct RootView: View {
    @EnvironmentObject var companionVM: CompanionViewModel
    @EnvironmentObject var emotionVM: EmotionViewModel
    @EnvironmentObject var speechVM: SpeechViewModel

    @State private var showSettings = false
    @State private var showFaceDebug = false
    @State private var touchActive = false   // tracks whether first onChanged has fired

    private let touchManager = TouchInteractionManager.shared

    var body: some View {
        ZStack {
            // The presence
            CompanionView()
                .environmentObject(companionVM)
                .environmentObject(speechVM)

            // Touch gesture layer — single unified gesture handles all tap/hold/drag
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let normalized = CGPoint(
                                    x: value.location.x / geo.size.width,
                                    y: value.location.y / geo.size.height
                                )
                                if !touchActive {
                                    touchActive = true
                                    touchManager.touchBegan(normalizedLocation: normalized)
                                } else {
                                    touchManager.dragChanged(
                                        normalizedLocation: normalized,
                                        absoluteLocation: value.location
                                    )
                                }
                            }
                            .onEnded { _ in
                                touchActive = false
                                touchManager.touchEnded()
                            }
                    )
            }  // end GeometryReader

            // Listening indicator — shows when wake word detected
            if speechVM.isListening {
                listeningRing
            }

            // Floating conversation bar
            conversationBar

            // Bottom-right buttons
            bottomButtons
        }
        .ignoresSafeArea()
        .onAppear {
            companionVM.startIdleLoop()
            // Start always-on wake word listening
            speechVM.startAlwaysOnListening()
            if KeychainManager.shared.loadAPIKey() == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showSettings = true
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(emotionVM)
                .environmentObject(companionVM)
        }
        .sheet(isPresented: $showFaceDebug) {
            FaceDebugView(accentColor: companionVM.eyeColor)
        }
    }

    // MARK: - Listening Ring

    private var listeningRing: some View {
        Circle()
            .stroke(companionVM.eyeColor.opacity(0.25), lineWidth: 1.5)
            .frame(width: 80, height: 80)
            .scaleEffect(speechVM.isListening ? 1.4 : 1.0)
            .opacity(speechVM.isListening ? 0.0 : 0.6)
            .animation(
                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                value: speechVM.isListening
            )
    }

    // MARK: - Conversation Bar

    private var conversationBar: some View {
        VStack {
            Spacer()

            let hasUser = !speechVM.transcribedText.trimmingCharacters(in: .whitespaces).isEmpty
            let hasResponse = !speechVM.responseText.trimmingCharacters(in: .whitespaces).isEmpty
            let hasError = speechVM.errorMessage != nil
            let hasContent = hasUser || hasResponse || hasError || speechVM.isThinking

            if hasContent {
                VStack(alignment: .leading, spacing: 6) {
                    if hasUser {
                        HStack(alignment: .top, spacing: 6) {
                            Text("You")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(width: 30, alignment: .leading)
                            Text(speechVM.transcribedText)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                    }

                    if speechVM.isThinking {
                        HStack(spacing: 6) {
                            Text("Pixo")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(companionVM.eyeColor.opacity(0.4))
                                .frame(width: 30, alignment: .leading)
                            Text("thinking…")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(companionVM.eyeColor.opacity(0.4))
                                .italic()
                        }
                    } else if hasResponse {
                        HStack(alignment: .top, spacing: 6) {
                            Text("Pixo")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(companionVM.eyeColor.opacity(0.5))
                                .frame(width: 30, alignment: .leading)
                            Text(speechVM.responseText)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(companionVM.eyeColor.opacity(0.85))
                                .lineLimit(3)
                        }
                    }

                    if let error = speechVM.errorMessage {
                        Text(error)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.red.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: hasContent)
            }
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // Face Recognition button
                    Button {
                        showFaceDebug = true
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "faceid")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }

                    // Settings button
                    Button {
                        showSettings = true
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "gearshape")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 48)
            }
        }
    }
}
