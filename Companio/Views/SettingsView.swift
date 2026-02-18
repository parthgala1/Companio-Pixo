import SwiftUI

// MARK: - SettingsView

/// Minimal settings sheet. 5 items only.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var emotionVM: EmotionViewModel
    @EnvironmentObject var companionVM: CompanionViewModel

    // MARK: - Eye Color Presets
    private let colorPresets: [(Color, String)] = [
        (.cyan,                         "#00E5FF"),
        (Color(hex: "#7B61FF") ?? .purple, "#7B61FF"),
        (Color(hex: "#FF6B6B") ?? .red,    "#FF6B6B"),
        (Color(hex: "#FFD93D") ?? .yellow,  "#FFD93D"),
        (Color(hex: "#6BCB77") ?? .green,   "#6BCB77"),
        (.white,                        "#FFFFFF"),
        (Color(hex: "#FF8C42") ?? .orange,  "#FF8C42"),
        (Color(hex: "#FF61D8") ?? .pink,    "#FF61D8"),
    ]

    // MARK: - State
    @State private var playFeaturesEnabled: Bool = UserDefaults.standard.bool(forKey: "pixo_play_enabled")
    @State private var silentModeEnabled: Bool = UserDefaults.standard.bool(forKey: "pixo_silent_mode")
    @State private var selectedVoiceID: String = "ecp3DWciuUyW7BYM7II1"
    @State private var showColorPicker: Bool = false
    @State private var customColor: Color = .cyan
    @State private var elevenLabsKey: String = ""
    @State private var groqKey: String = ""
    @State private var keySaved: Bool = false
    @State private var groqKeySaved: Bool = false

    private let voiceOptions: [(String, String)] = [
        ("Pixo",    "ecp3DWciuUyW7BYM7II1"),  // Custom voice
        ("Bella",   "EXAVITQu4vr4xnSDxMaL"),
        ("Rachel",  "21m00Tcm4TlvDq8ikWAM"),
        ("Domi",    "AZnzlk1XvdvUeBnXmlld"),
        ("Elli",    "MF3mGyEYCl7XYWbV9V6O"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Live preview of the eye
                        eyePreview

                        // 1. Eye color
                        colorSection

                        // 2. Play features toggle
                        settingsToggle(
                            title: "Play Features",
                            subtitle: "Dance, copy me, staring contest…",
                            isOn: $playFeaturesEnabled
                        ) {
                            UserDefaults.standard.set(playFeaturesEnabled, forKey: "pixo_play_enabled")
                        }

                        // 3. Silent mode toggle
                        settingsToggle(
                            title: "Silent Mode",
                            subtitle: "Pixo listens but doesn't speak",
                            isOn: $silentModeEnabled
                        ) {
                            UserDefaults.standard.set(silentModeEnabled, forKey: "pixo_silent_mode")
                        }

                        // 4. Voice selection
                        voiceSection

                        // 5. Groq API key
                        groqKeySection

                        // 6. ElevenLabs API key
                        elevenLabsKeySection

                        // 7. Reset emotion state
                        resetButton
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Pixo")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(companionVM.eyeColor)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Eye Preview

    private var eyePreview: some View {
        HStack(spacing: 28) {
            EyeView(
                blinkProgress: 0.0,
                pupilOffset: .zero,
                pupilScale: 1.0,
                eyeColor: companionVM.eyeColor,
                eyeSize: 56
            )
            EyeView(
                blinkProgress: 0.0,
                pupilOffset: CGPoint(x: 0.2, y: 0.1),
                pupilScale: 1.0,
                eyeColor: companionVM.eyeColor,
                eyeSize: 56
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Color Section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Eye Color")

            // Preset swatches
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                ForEach(colorPresets, id: \.1) { (color, hex) in
                    colorSwatch(color: color, hex: hex)
                }
            }

            // Custom color picker
            Button {
                showColorPicker.toggle()
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(customColor)
                        .frame(width: 28, height: 28)
                    Text("Custom color")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                }
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedColor: $customColor) { color in
                    companionVM.setEyeColor(color)
                }
            }
        }
    }

    private func colorSwatch(color: Color, hex: String) -> some View {
        let isSelected = companionVM.eyeColor.toHex()?.uppercased() == hex.uppercased()
        return Button {
            companionVM.setEyeColor(color)
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 36, height: 36)
                .shadow(color: color.opacity(0.7), radius: isSelected ? 8 : 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Voice")
            HStack(spacing: 0) {
                ForEach(voiceOptions, id: \.1) { (name, id) in
                    let isSelected = selectedVoiceID == id
                    Button {
                        selectedVoiceID = id
                        ElevenLabsService.shared.voiceID = id
                    } label: {
                        Text(name)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? companionVM.eyeColor : Color.clear)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
            }
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Groq Key Section

    private var groqKeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Groq API Key")

            HStack(spacing: 10) {
                SecureField("Paste your Groq key…", text: $groqKey)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .onAppear {
                        groqKey = KeychainManager.shared.loadAPIKey() ?? ""
                    }

                Button {
                    KeychainManager.shared.saveAPIKey(groqKey)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { groqKeySaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { groqKeySaved = false }
                    }
                } label: {
                    Image(systemName: groqKeySaved ? "checkmark" : "arrow.down.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(groqKeySaved ? .green : companionVM.eyeColor)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            // Status
            HStack(spacing: 6) {
                let hasKey = !(KeychainManager.shared.loadAPIKey() ?? "").isEmpty
                Circle()
                    .fill(hasKey ? Color.green : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
                Text(hasKey ? "Key saved — Groq LLM active" : "No key — Pixo can't respond")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    // MARK: - ElevenLabs Key Section

    private var elevenLabsKeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("ElevenLabs API Key")

            HStack(spacing: 10) {
                SecureField("Paste your API key…", text: $elevenLabsKey)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .onAppear {
                        elevenLabsKey = KeychainManager.shared.loadElevenLabsAPIKey() ?? ""
                    }

                Button {
                    KeychainManager.shared.saveElevenLabsAPIKey(elevenLabsKey)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { keySaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { keySaved = false }
                    }
                } label: {
                    Image(systemName: keySaved ? "checkmark" : "arrow.down.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(keySaved ? .green : companionVM.eyeColor)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            // Status
            HStack(spacing: 6) {
                let hasKey = !(KeychainManager.shared.loadElevenLabsAPIKey() ?? "").isEmpty
                Circle()
                    .fill(hasKey ? Color.green : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
                Text(hasKey ? "Key saved — ElevenLabs voice active" : "No key — using system voice")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            EmotionEngine.shared.resetState()
        } label: {
            Text("Reset Emotion State")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.25))
            .kerning(1.5)
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>, onChange: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(companionVM.eyeColor)
                .onChange(of: isOn.wrappedValue) { _ in onChange() }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ColorPickerSheet

struct ColorPickerSheet: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Color) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ColorPicker("Choose a color", selection: $selectedColor, supportsOpacity: false)
                    .padding(32)
                    .labelsHidden()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSelect(selectedColor)
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
