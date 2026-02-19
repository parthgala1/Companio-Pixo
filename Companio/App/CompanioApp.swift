import SwiftUI

@main
struct CompanioApp: App {
    // MARK: - Services (singletons, created once at app launch)
    @StateObject private var emotionEngine = EmotionEngine.shared
    @StateObject private var soundService = SoundService.shared
    @StateObject private var memoryService = MemoryService.shared

    // MARK: - ViewModels
    @StateObject private var companionVM: CompanionViewModel
    @StateObject private var emotionVM: EmotionViewModel
    @StateObject private var speechVM: SpeechViewModel

    init() {
        let engine = EmotionEngine.shared
        let sound = SoundService.shared
        let memory = MemoryService.shared
        let touch = TouchInteractionManager.shared

        let eVM = EmotionViewModel(emotionEngine: engine, soundService: sound)
        let cVM = CompanionViewModel(emotionEngine: engine, soundService: sound, touchManager: touch, batteryService: BatteryService.shared)
        let sVM = SpeechViewModel(
            emotionEngine: engine,
            memoryService: memory,
            soundService: sound
        )

        _companionVM = StateObject(wrappedValue: cVM)
        _emotionVM = StateObject(wrappedValue: eVM)
        _speechVM = StateObject(wrappedValue: sVM)

        // Wire CompanionVM into the speech + play mode pipeline
        sVM.configure(companionVM: cVM)

        // Warm up ElevenLabs audio engine
        _ = ElevenLabsService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(companionVM)
                .environmentObject(emotionVM)
                .environmentObject(speechVM)
                .preferredColorScheme(.dark)
        }
    }
}
