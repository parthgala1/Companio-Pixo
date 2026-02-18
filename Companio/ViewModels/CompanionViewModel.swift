import Foundation
import Combine
import SwiftUI

// MARK: - CompanionViewModel

/// Drives all animation state for the companion face.
/// Subscribes to FaceDetectionService and EmotionEngine to update animation parameters.
final class CompanionViewModel: ObservableObject {

    // MARK: - Eye Color (persisted)
    @AppStorage("pixo_eye_color_hex") private var eyeColorHex: String = "#00E5FF"

    var eyeColor: Color {
        Color(hex: eyeColorHex) ?? .cyan
    }

    func setEyeColor(_ color: Color) {
        eyeColorHex = color.toHex() ?? "#00E5FF"
        objectWillChange.send()
    }

    // MARK: - Animation State (observed by Views)
    @Published var leftEyeBlinkProgress: Double = 0.0
    @Published var rightEyeBlinkProgress: Double = 0.0
    @Published var pupilOffset: CGPoint = .zero
    @Published var pupilScale: Double = 1.0
    @Published var mouthState: MouthState = .neutral
    @Published var faceGlowColor: Color = .cyan
    @Published var currentBehavior: BehaviorType = .idle
    @Published var isThinking: Bool = false
    @Published var browTilt: Double = 0.0   // -1 = outer raised (happy), +1 = inner raised (concerned)

    // MARK: - Emote State
    /// Currently active emote. When non-nil, overrides normal behavior-driven expressions.
    @Published var activeEmote: PixoEmote? = nil

    // MARK: - Overlay Stack (max 3 ephemeral overlays)
    @Published var activeOverlays: [ActiveOverlay] = []
    @Published var glowIntensity: Double = 1.0
    @Published var angerShakeOffset: CGFloat = 0.0
    @Published var smallEyesActive: Bool = false

    // MARK: - New State
    @Published var handMood: HandMood? = nil       // nil = hands hidden
    @Published var idleFloatOffset: CGFloat = 0.0  // ±3px sine drift
    @Published var arousalScale: Double = 0.0       // 0–1, drives face scale

    // MARK: - Touch Visual State
    @Published var touchScale: CGFloat = 1.0        // Press/release spring
    @Published var faceTiltAngle: Double = 0.0      // Lean toward touch, ±3°

    // MARK: - Dependencies
    private let emotionEngine: EmotionEngine
    private let faceDetectionService: FaceDetectionService
    private let soundService: SoundService
    private let touchManager: TouchInteractionManager

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Timers
    private var blinkTimer: Timer?
    private var idleTimer: Timer?
    private var behaviorTimer: Timer?
    private var idlePhase: Double = 0.0

    /// True while speech-driven mouth animation is active.
    /// Prevents emotion updates from overriding talking mouth state.
    private var isTalking = false

    /// Prevents blink scheduler from resetting squint during touch reactions.
    private var isTouchSquinting = false

    /// Visual decay timer for smooth post-reaction return to neutral.
    private var visualDecayTimer: Timer?

    /// True while a touch reaction is playing out or decaying.
    private var isReacting = false

    /// Timer that auto-clears a time-limited emote.
    private var emoteTimer: Timer?

    // MARK: - Init
    init(emotionEngine: EmotionEngine = .shared,
         faceDetectionService: FaceDetectionService = .shared,
         soundService: SoundService = .shared,
         touchManager: TouchInteractionManager = .shared) {
        self.emotionEngine = emotionEngine
        self.faceDetectionService = faceDetectionService
        self.soundService = soundService
        self.touchManager = touchManager
        bindToServices()
    }

    // MARK: - Bindings

    private func bindToServices() {
        faceDetectionService.faceDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.handleFaceEvent(event) }
            .store(in: &cancellables)

        faceDetectionService.faceLostPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleFaceLost() }
            .store(in: &cancellables)

        emotionEngine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.updateExpression(from: state) }
            .store(in: &cancellables)

        // Observe mouth openness from SpeechService / ElevenLabsService
        NotificationCenter.default.publisher(for: .companioMouthOpenness)
            .receive(on: DispatchQueue.main)
            .compactMap { $0.userInfo?["openness"] as? Double }
            .sink { [weak self] openness in
                guard let self else { return }
                if openness > 0.01 {
                    self.setTalking(level: openness)
                } else {
                    self.stopTalking()
                }
            }
            .store(in: &cancellables)

        // MARK: Touch Subscriptions

        // Resolved touch events — final classification on release
        touchManager.touchEventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.handleTouchEvent(event) }
            .store(in: &cancellables)

        // Progressive duration feedback — runs at 20 Hz while touching
        touchManager.$currentDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in self?.updateProgressiveTouchFeedback(duration: duration) }
            .store(in: &cancellables)

        // Touch phase changes — press/release visual feedback
        touchManager.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in self?.updateTouchPhaseVisual(phase) }
            .store(in: &cancellables)
    }

    // MARK: - Face Event Handling

    private func handleFaceEvent(_ event: FaceEvent) {
        let targetOffset = CGPoint(x: event.horizontalOffset * 0.28, y: 0)
        withAnimation(.easeOut(duration: 0.14)) {
            pupilOffset = targetOffset
        }
        emotionEngine.onFaceDetected(proximity: event.proximityRatio, offset: event.horizontalOffset)
    }

    private func handleFaceLost() {
        withAnimation(.easeOut(duration: 0.5)) { pupilOffset = .zero }
        emotionEngine.onFaceLost()
    }

    // MARK: - Expression Update

    private func updateExpression(from state: EmotionState) {
        // Don't override emote-driven expression
        guard activeEmote == nil else { return }

        // Use the current behavior — behavior rotation is handled by the
        // 8-second behaviorCycle timer. Re-selecting here with weighted
        // randomness caused the mouth to flicker on every emotion tick.
        let behavior = currentBehavior

        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            arousalScale = state.arousal
            // Only update mouth from emotion when not speaking
            if !isTalking {
                mouthState = mouthState(for: state, behavior: behavior)
            }
            browTilt = browTiltValue(for: behavior)
            pupilScale = behavior.pupilScale
            faceGlowColor = eyeColor  // Glow always matches eye color
        }
    }

    private func mouthState(for state: EmotionState, behavior: BehaviorType) -> MouthState {
        if isThinking { return .neutral }

        // Mouth stays neutral/closed during idle — only opens when speaking
        // or during a brief reaction (tap, rub, etc.)
        return .neutral
    }

    private func browTiltValue(for behavior: BehaviorType) -> Double {
        switch behavior {
        case .sad:                  return 0.55   // inner raised — worried look
        case .thinking:             return 0.3    // slight inner raise — pondering
        case .excited:              return -0.2   // both slightly raised — wide-eyed
        case .happy, .playful:      return -0.15  // relaxed arch — warm
        case .curious, .attentive:  return -0.35  // outer raised — inquisitive
        case .sleepy:               return 0.1    // drooping slightly
        case .idle:                 return 0.0    // flat neutral
        }
    }


    func startIdleLoop() {
        startBlinkScheduler()
        startIdleMicroAnimation()
        startBehaviorCycle()
        faceDetectionService.start()
    }

    func stopIdleLoop() {
        blinkTimer?.invalidate()
        idleTimer?.invalidate()
        behaviorTimer?.invalidate()
        faceDetectionService.stop()
        // Cancel the repeating idle float and settle at center
        withAnimation(.easeInOut(duration: 0.3)) {
            idleFloatOffset = 0.0
        }
    }

    // MARK: - Blink Scheduler

    private func startBlinkScheduler() { scheduleBlink() }

    private func scheduleBlink() {
        // Arousal affects blink rate: higher arousal = faster blinks
        // Clamp arousal influence so blinks never go below 2.0s
        let baseInterval = Double.random(in: 3.0...6.0)
        let arousalFactor = max(0.65, 1.0 - emotionEngine.state.arousal * 0.3)
        let interval = baseInterval * arousalFactor

        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Skip blinks while touch is actively squinting eyes,
            // while Pixo is speaking, or while thinking
            if self.isTouchSquinting || self.isTalking || self.isThinking {
                self.scheduleBlink()
                return
            }
            self.performBlink()
        }
    }

    private func performBlink() {
        soundService.playBlink(emotionState: emotionEngine.state)
        executeBlink()

        // Occasional double blink (~20% chance)
        if Double.random(in: 0...1) < 0.2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                self?.executeBlink()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.scheduleBlink()
        }
    }

    private func executeBlink() {
        withAnimation(.easeInOut(duration: 0.09)) { leftEyeBlinkProgress = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.easeInOut(duration: 0.09)) { self.rightEyeBlinkProgress = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.easeOut(duration: 0.1)) {
                self.leftEyeBlinkProgress = 0.0
                self.rightEyeBlinkProgress = 0.0
            }
        }
    }

    // MARK: - Idle Micro Animation (±3px float)

    private func startIdleMicroAnimation() {
        // Smooth continuous ±3px sinusoidal float — single repeating animation
        // eliminates the jitter from discrete timer-driven steps.
        idleFloatOffset = -3.0
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            idleFloatOffset = 3.0
        }

        // Pupil drift timer — only for subtle eye tracking, uses longer animation
        // duration to overlap steps and produce smooth rolling motion.
        idleTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.tickPupilDrift()
        }
    }

    private func tickPupilDrift() {
        idlePhase += 0.04
        guard faceDetectionService.lastFaceEvent == nil else { return }
        let driftX = sin(idlePhase * 0.7) * 0.05
        let driftY = cos(idlePhase * 0.5) * 0.03
        // Subtle unpredictability — adds aliveness
        let jitterX = Double.random(in: -0.005...0.005)
        let jitterY = Double.random(in: -0.003...0.003)
        withAnimation(.easeInOut(duration: 0.25)) {
            pupilOffset = CGPoint(x: driftX + jitterX, y: driftY + jitterY)
        }
    }

    // MARK: - Behavior Cycle

    private func startBehaviorCycle() {
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            // Skip behavior changes while an emote is manually active
            guard self.activeEmote == nil else { return }

            let newBehavior = self.emotionEngine.selectBehavior()
            if newBehavior != self.currentBehavior {
                withAnimation(.easeInOut(duration: 0.5)) { self.currentBehavior = newBehavior }
                if let cue = newBehavior.soundCue {
                    self.soundService.play(cue, emotionState: self.emotionEngine.state)
                }
            }

            // Occasionally auto-trigger an emote based on the current mood
            // ~20% chance per cycle, adds personality
            if Double.random(in: 0...1) < 0.20 {
                if let emote = self.emoteForCurrentMood() {
                    self.showEmote(emote, duration: 4.0)
                }
            }
        }
    }

    /// Selects a PixoEmote based on the current dominant mood and energy.
    private func emoteForCurrentMood() -> PixoEmote? {
        let state = emotionEngine.state
        let mood = state.dominantMood

        switch mood {
        case .excited:
            return [.joyful, .singing, .laughing].randomElement()
        case .happy:
            return [.happy, .wink, .proud].randomElement()
        case .neutral:
            return state.boredomLevel > 0.6 ? .confused : nil
        case .anxious:
            return [.shocked, .confused].randomElement()
        case .sad:
            return .sad
        case .sleepy:
            return state.energy < 0.2 ? .lowBattery : .sleeping
        }
    }

    // MARK: - Hands Control

    func showHands(mood: HandMood) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            handMood = mood
        }
    }

    func hideHands() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            handMood = nil
        }
    }

    // MARK: - Emote Control

    /// Activates a Pixo emote, overriding normal behavior-driven expression.
    /// - Parameters:
    ///   - emote: The emote to display.
    ///   - duration: How long to hold it before auto-clearing (nil = indefinite, clear manually).
    func showEmote(_ emote: PixoEmote, duration: TimeInterval? = 3.0) {
        emoteTimer?.invalidate()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            activeEmote = emote

            // Apply emote-driven visual overrides
            mouthState = emote.mouthState
            browTilt = emote.browTilt
            pupilScale = emote.pupilScale
            currentBehavior = emote.behaviorType

            // Handle special eye states for emotes that use blink progress
            switch emote {
            case .wink:
                leftEyeBlinkProgress = 0.0   // wink uses EyeStyle, not blink
                rightEyeBlinkProgress = 0.0
            case .sleeping:
                leftEyeBlinkProgress = 0.0   // sleep uses EyeStyle
                rightEyeBlinkProgress = 0.0
            case .laughing:
                leftEyeBlinkProgress = 0.0   // squint uses EyeStyle
                rightEyeBlinkProgress = 0.0
            default:
                break
            }
        }

        // Auto-clear after duration
        if let duration {
            emoteTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.clearEmote()
            }
        }
    }

    /// Clears the active emote and returns to normal behavior-driven expression.
    func clearEmote() {
        emoteTimer?.invalidate()
        emoteTimer = nil

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            activeEmote = nil
            // Restore behavior-driven state
            let state = emotionEngine.state
            mouthState = mouthState(for: state, behavior: currentBehavior)
            browTilt = browTiltValue(for: currentBehavior)
            pupilScale = currentBehavior.pupilScale
            leftEyeBlinkProgress = 0.0
            rightEyeBlinkProgress = 0.0
        }
    }

    // MARK: - Overlay Stack Management

    /// Adds an ephemeral overlay. Max 3 at once — extras are silently dropped.
    func addOverlay(_ type: EmoteOverlayElement, duration: TimeInterval = 2.0) {
        guard activeOverlays.count < 3 else { return }
        let overlay = ActiveOverlay(type: type, duration: duration)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeOverlays.append(overlay)
        }
        let overlayID = overlay.id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.activeOverlays.removeAll { $0.id == overlayID }
            }
        }
    }

    /// Clears all overlays immediately.
    func clearOverlays() {
        withAnimation(.easeOut(duration: 0.2)) {
            activeOverlays.removeAll()
        }
    }

    /// Triggers a staggered, layered affection sequence during petting.
    /// Blush → hearts → sparkle, with glow intensification.
    func triggerPettingSequence() {
        clearOverlays()
        addOverlay(.blushWide, duration: 3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.addOverlay(.tinyHeartsFloat, duration: 2.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            self?.addOverlay(.sparkle, duration: 2.0)
        }
        // Glow intensification — warm, not harsh
        withAnimation(.easeInOut(duration: 0.5)) { glowIntensity = 1.4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.8)) { self?.glowIntensity = 1.0 }
        }
    }

    /// Quick horizontal jitter + anger pulse overlay for anger reactions.
    func triggerAngerShake() {
        addOverlay(.angerPulse, duration: 2.5)
        let steps: [(offset: CGFloat, delay: Double)] = [
            (2.0,  0.0),
            (-2.0, 0.04),
            (1.5,  0.08),
            (-1.0, 0.12),
            (0.0,  0.16)
        ]
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) { [weak self] in
                let anim: Animation = step.offset == 0
                    ? .easeOut(duration: 0.1)
                    : .linear(duration: 0.04)
                withAnimation(anim) { self?.angerShakeOffset = step.offset }
            }
        }
    }

    /// Checks if “small eyes” affection mode should activate.
    func checkSmallEyesMode(petDuration: TimeInterval) {
        let attachment = emotionEngine.state.attachmentScore
        let shouldActivate = attachment > 0.6 && petDuration > 1.5
        if shouldActivate != smallEyesActive {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                smallEyesActive = shouldActivate
            }
        }
    }

    // MARK: - Mouth Control (called by SpeechViewModel)

    func setTalking(level: Double) {
        isTalking = true
        withAnimation(.easeInOut(duration: 0.05)) {
            mouthState = .talking(level: CGFloat(level))
        }
    }

    func stopTalking() {
        isTalking = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let state = emotionEngine.state
            mouthState = mouthState(for: state, behavior: currentBehavior)
        }
    }

    func setThinking(_ thinking: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isThinking = thinking
            if thinking { mouthState = .neutral }
        }
    }

    // MARK: - Touch Reactions

    // MARK: Progressive Touch Feedback (runs at 20 Hz during touch)

    /// Provides real-time visual feedback as touch duration increases.
    /// Eyes gradually narrow, brows knit, mouth flattens — never an instant jump.
    private func updateProgressiveTouchFeedback(duration: TimeInterval) {
        // During petting, check for small eyes mode activation
        if touchManager.phase == .petting {
            checkSmallEyesMode(petDuration: duration)
            return
        }
        guard touchManager.phase == .touching else { return }
        guard !isTalking else { return }

        if duration < 0.2 {
            // Light touch territory — only press scale, reaction on release
            return
        } else if duration < 0.6 {
            // Hold — curious
            let progress = (duration - 0.2) / 0.4  // 0…1
            withAnimation(.easeInOut(duration: 0.1)) {
                browTilt = -0.25 * progress  // outer raised — inquisitive
                mouthState = .neutral
            }
        } else if duration < 1.2 {
            // Long press — irritation builds gradually
            let progress = (duration - 0.6) / 0.6  // 0…1
            isTouchSquinting = true
            withAnimation(.easeInOut(duration: 0.1)) {
                leftEyeBlinkProgress = progress * 0.35
                rightEyeBlinkProgress = progress * 0.35
                browTilt = progress * 0.55   // inner raised — knitting
                mouthState = .neutral        // flattening toward displeasure
            }
        } else {
            // Over-hold — anger intensifies
            let overProgress = min((duration - 1.2) / 0.8, 1.0)  // 0…1
            isTouchSquinting = true
            withAnimation(.easeInOut(duration: 0.08)) {
                leftEyeBlinkProgress = 0.35 + overProgress * 0.15   // up to 0.5
                rightEyeBlinkProgress = 0.35 + overProgress * 0.15
                browTilt = 0.55 + overProgress * 0.2               // max 0.75
                mouthState = .frown
            }
        }
    }

    // MARK: Touch Phase Visual (press/release bounce)

    /// Applies physical feedback: scale down on press, bounce on release.
    /// Also handles petting visuals (half-closed eyes, smile, face lean).
    private func updateTouchPhaseVisual(_ phase: TouchPhase) {
        switch phase {
        case .idle:
            break

        case .touching:
            // Tiny scale-down — like a physical press
            isReacting = true
            visualDecayTimer?.invalidate()
            withAnimation(.spring(response: 0.1, dampingFraction: 0.7)) {
                touchScale = 0.97
            }

        case .petting:
            // Transition to affection visuals with layered overlays
            isReacting = true
            isTouchSquinting = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                mouthState = .smile
                browTilt = -0.2     // relaxed arch
                leftEyeBlinkProgress = 0.28   // half-closed, content
                rightEyeBlinkProgress = 0.28
                touchScale = 1.0
            }
            showHands(mood: .shy)
            updateFaceTilt()
            triggerPettingSequence()
            soundService.play(.happy, emotionState: emotionEngine.state)

        case .releasing:
            // Spring overshoot bounce
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                touchScale = 1.03
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self?.touchScale = 1.0
                }
            }
        }
    }

    // MARK: Resolved Touch Event Handler

    /// Called once when touch ends with a fully classified event.
    /// Triggers final reaction + EmotionEngine update.
    private func handleTouchEvent(_ event: TouchEvent) {
        // Update emotion state
        emotionEngine.onTouchEvent(event)

        switch event.type {
        case .lightTap:
            triggerLightTap()
        case .hold:
            triggerHoldReaction()
        case .longPress:
            triggerIrritationReaction(duration: event.duration)
        case .overHold:
            triggerAngerReaction(duration: event.duration)
        case .petting:
            triggerPettingEnd(abrupt: event.duration < 0.8)
        }
    }

    // MARK: Reaction Implementations

    private func triggerLightTap() {
        // Happy bounce + emote
        showEmote(.wink, duration: 1.5)
        soundService.play(.happy, emotionState: emotionEngine.state)
        performBlink()
        startVisualDecay(after: 1.5)
    }

    private func triggerHoldReaction() {
        // Curious expression — confused emote
        showEmote(.confused, duration: 2.0)
        startVisualDecay(after: 2.0)
    }

    private func triggerIrritationReaction(duration: TimeInterval) {
        // Squint + frown — sad emote
        showEmote(.sad, duration: 2.5)
        soundService.play(.thinking, emotionState: emotionEngine.state)
        startVisualDecay(after: 2.5)
    }

    private func triggerAngerReaction(duration: TimeInterval) {
        // Full anger expression with shake + pulse
        showEmote(.shocked, duration: 3.0)
        triggerAngerShake()
        startVisualDecay(after: 3.0)
    }

    private func triggerPettingEnd(abrupt: Bool) {
        if abrupt {
            // Abrupt stop — confused
            showEmote(.confused, duration: 1.5)
            startVisualDecay(after: 1.5)
        } else {
            // Gentle end — love emote
            showEmote(.love, duration: 2.5)
            startVisualDecay(after: 2.5)
        }
    }

    // MARK: Face Tilt (Lean Toward Touch)

    /// Tilts the face slightly toward the touch point during petting.
    private func updateFaceTilt() {
        let nx = touchManager.normalizedTouchLocation.x
        // Map 0–1 to ±3° tilt
        let tilt = (nx - 0.5) * 6.0  // -3° to +3°
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            faceTiltAngle = tilt
        }
    }

    // MARK: Visual Decay (Gradual Return to Neutral)

    /// After a reaction, smoothly decays all visual overrides back to neutral.
    /// No hard resets — exponential decay at ~20 Hz.
    private func startVisualDecay(after delay: TimeInterval) {
        visualDecayTimer?.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.isTouchSquinting = false

            self.visualDecayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    var settled = true

                    // Decay brow tilt toward 0
                    if abs(self.browTilt) > 0.01 {
                        self.browTilt *= 0.92
                        settled = false
                    } else {
                        self.browTilt = 0
                    }

                    // Decay eye blink/squint toward 0
                    if self.leftEyeBlinkProgress > 0.01 && !self.isTalking {
                        self.leftEyeBlinkProgress *= 0.90
                        self.rightEyeBlinkProgress *= 0.90
                        if self.leftEyeBlinkProgress < 0.02 {
                            self.leftEyeBlinkProgress = 0
                            self.rightEyeBlinkProgress = 0
                        }
                        settled = false
                    }

                    // Decay face tilt toward 0
                    if abs(self.faceTiltAngle) > 0.05 {
                        self.faceTiltAngle *= 0.90
                        settled = false
                    } else {
                        self.faceTiltAngle = 0
                    }

                    // Once everything is close enough, snap and stop
                    if settled {
                        self.visualDecayTimer?.invalidate()
                        self.visualDecayTimer = nil
                        self.isReacting = false
                        self.clearEmote()
                        self.clearOverlays()
                        self.smallEyesActive = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.mouthState = .neutral
                            self.currentBehavior = self.emotionEngine.selectBehavior()
                        }
                        self.hideHands()
                    }
                }
            }
        }
    }
}

// MARK: - Color Hex Extensions

extension Color {
    init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexStr = hexStr.hasPrefix("#") ? String(hexStr.dropFirst()) : hexStr
        guard hexStr.count == 6, let value = UInt64(hexStr, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
