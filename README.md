# Pixo — Affective AI Companion for iOS

A minimalist, emotionally intelligent AI companion built with SwiftUI. Pixo lives on your screen as a glowing face that listens, speaks, emotes, and bonds with you over time.

No buttons. No chrome. Just a presence.

---

## Architecture

```
CompanioApp
├── RootView (touch gesture layer + conversation bar + settings)
│   ├── CompanionView (black canvas + ambient glow)
│   │   └── CompanionFaceView (eyes + mouth + hands + overlays)
│   │       ├── EyeView × 2 (7 styles: normal, round, spiral, wink, squint, sleep, hidden)
│   │       ├── MouthView (Bezier morphing: smile, frown, surprise, talk, wavy, bored)
│   │       ├── HandsView (shy, celebrate, embarrass, copy, dance)
│   │       └── EmoteOverlayView (16 overlay types, max 3 stacked)
│   └── SettingsView (eye color, voice, API keys, toggles)
├── ViewModels
│   ├── CompanionViewModel (animation state, emotes, overlay stack, touch reactions)
│   ├── SpeechViewModel (STT → intent routing → LLM → TTS pipeline)
│   ├── PlayModeViewModel (9 interactive play modes)
│   └── EmotionViewModel (emotion state bridge)
├── Services
│   ├── EmotionEngine (5-axis emotional model with decay + time-of-day)
│   ├── LLMService (Groq API — llama-3.3-70b)
│   ├── ElevenLabsService (voice synthesis + mouth sync)
│   ├── SpeechService (Apple STT + always-on wake word)
│   ├── IntentRouter (keyword → command classification)
│   ├── FaceDetectionService (Apple Vision — front camera)
│   ├── TouchInteractionManager (tap/hold/pet state machine)
│   ├── SoundService (AVAudioEngine + emotion-modulated pitch)
│   ├── MemoryService (conversation history for LLM context)
│   ├── BlinkDetectionManager (staring contest blink detection)
│   ├── CopyModeManager (face expression mirroring)
│   └── DanceAnimationController (120 BPM beat sync)
└── Models
    ├── EmotionState (valence, arousal, energy, attachment, boredom)
    ├── PixoEmote (12 emotes + overlay system)
    ├── BehaviorType (idle, happy, sad, curious, excited, etc.)
    └── FeatureCommand (9 routed commands)
```

## Features

### Voice & Conversation

- **"Hey Pixo"** wake word — always-on listening via `SFSpeechRecognizer`
- Transcribed speech routed through `IntentRouter` (keyword match → 9 commands, fallback → LLM)
- Groq API (`llama-3.3-70b-versatile`) generates 3-sentence max responses
- ElevenLabs voice synthesis with emotion-conditioned stability/style parameters
- Falls back to Apple system TTS (`Samantha`) when no ElevenLabs key is set
- Amplitude-based mouth sync at 20Hz during speech

### Emotional Intelligence

- **5-axis emotion model:** valence (affect), arousal (activation), energy, attachment (bond), boredom
- Emotion decays toward baseline over time — anger and excitement don't persist forever
- Time-of-day modulation (sleepy at night, energetic in morning)
- Boredom grows with inactivity, resets on interaction
- Sentiment analysis of LLM responses feeds back into emotion state
- All state persisted to `UserDefaults` across launches

### Touch Interaction

- **Light tap** (< 0.2s) → happy bounce + wink emote
- **Hold** (0.2–0.6s) → curious expression
- **Long press** (0.6–1.2s) → irritation builds progressively
- **Over-hold** (1.2s+) → anger with shake animation + red pulse mark
- **Petting** (smooth drag) → staggered affection: blush → floating hearts → sparkles, glow intensifies, face leans toward touch
- **Small eyes mode** activates when attachment > 0.6 and pet duration > 1.5s

### 12 Emotes

| Emote       | Eyes                          | Mouth      | Overlay         |
| ----------- | ----------------------------- | ---------- | --------------- |
| Wink        | Left closed arc, right normal | Smile      | —               |
| Happy       | Normal                        | Smile      | —               |
| Confused    | Normal, brows raised          | Smile      | ?               |
| Proud       | Normal                        | Neutral    | Thumbs up       |
| Joyful      | Normal, dilated               | Smile      | —               |
| Sad         | Round                         | Wavy frown | Tears           |
| Singing     | Spiral                        | Wavy smile | Music notes     |
| Shocked     | Round, dilated                | Surprise O | —               |
| Low Battery | Spiral                        | Bored      | Battery + notes |
| Laughing    | Happy squint                  | Frown arc  | HA              |
| Sleeping    | Sleep lines                   | Surprise O | ZZZ             |
| Love        | Hidden                        | Hidden     | Heart           |

### Overlay Stack

- Max 3 ephemeral overlays at once — auto-expire after duration
- Staggered timing (0ms → 150ms → 300ms) for organic feel
- 16 overlay types: `?`, thumbs up, tears, music notes, battery, HA, ZZZ, heart, sparkle, tiny hearts, blush, love aura, bounce lines, soft halo, anger pulse, humming note
- All vector-based `Shape` structs — no PNGs

### 9 Play Modes

| Command          | Trigger Phrase    | Description                               |
| ---------------- | ----------------- | ----------------------------------------- |
| Copy Me          | "copy me"         | Mirrors user's face via front camera      |
| Dance            | "dance"           | 120 BPM beat animation with singing emote |
| Guess Mood       | "guess my mood"   | Reads emotion state and guesses           |
| Story            | "tell me a story" | LLM generates 3-sentence story            |
| Staring Contest  | "staring contest" | Blink detection via face tracking loss    |
| Compliment       | "compliment me"   | LLM generates heartfelt compliment        |
| Roast            | "roast me"        | LLM generates playful safe roast          |
| Silent Companion | "silent mode"     | Quiet presence, minimal animation         |
| Stop             | "stop"            | Ends any active mode                      |

### Face Detection

- Apple Vision `VNDetectFaceRectanglesRequest` at 10fps
- Pupil tracking follows detected face horizontally
- Proximity sensing via face bounding box size
- Face loss triggers emotion shift (arousal down, boredom up)

### Ambient Life

- Sinusoidal ±3px idle float animation
- Pupil drift when no face detected (with subtle random jitter)
- Arousal-modulated blink rate with 20% double-blink chance
- Behavior cycle rotates every 8s (idle → curious → playful → etc.)
- 20% chance of spontaneous emote per behavior cycle

---

## Requirements

- iOS 17.0+
- Swift 5.9
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (project generation)

## Setup

```bash
# 1. Clone
git clone <repo-url> && cd Companio

# 2. Generate Xcode project
xcodegen generate

# 3. Open in Xcode
open Companio.xcodeproj
```

### API Keys

Set in Settings (gear icon, bottom-right):

| Key                    | Required | Purpose                                                                                               |
| ---------------------- | -------- | ----------------------------------------------------------------------------------------------------- |
| **Groq API Key**       | Yes      | Powers all LLM responses ([console.groq.com](https://console.groq.com))                               |
| **ElevenLabs API Key** | No       | Premium voice synthesis; falls back to system TTS without it ([elevenlabs.io](https://elevenlabs.io)) |

Keys are stored in the iOS Keychain — not in code or UserDefaults.

### Privacy Permissions

The app requires these entitlements (add to `Info.plist` if not present):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Pixo needs the microphone to listen for your voice.</string>
<key>NSCameraUsageDescription</key>
<string>Pixo uses the camera to detect your face for interactive features.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Pixo uses speech recognition to understand what you say.</string>
```

---

## Project Structure

```
Companio/
├── App/                    # Entry point + root view
├── Models/                 # EmotionState, PixoEmote, BehaviorType, etc.
├── Services/               # Singletons: LLM, TTS, STT, emotion, touch, face, sound
├── ViewModels/             # MVVM: CompanionVM, SpeechVM, PlayModeVM, EmotionVM
├── Views/                  # SwiftUI: EyeView, MouthView, HandsView, overlays
├── Utilities/              # Extensions, KeychainManager
├── Resources/              # PersonalityPrompt.txt
└── Assets/Sounds/          # 8 WAV files (blink, happy, thinking, dance, etc.)
```

## Settings

| Toggle        | Effect                                                       |
| ------------- | ------------------------------------------------------------ |
| Eye Color     | 8 presets + custom color picker; persisted via `@AppStorage` |
| Voice         | 5 ElevenLabs voices (Pixo, Bella, Rachel, Domi, Elli)        |
| Play Features | Enables/disables interactive play modes                      |
| Silent Mode   | Pixo listens but doesn't speak — text responses only         |
| Reset Emotion | Returns all 5 emotion axes to defaults                       |

---

## License

Private project. All rights reserved.
