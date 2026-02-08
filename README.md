# VoiceType

A minimal macOS menu bar app for push-to-talk speech transcription using whisper.cpp with Core ML acceleration. Runs 100% locally with no cloud dependencies.

## Features

- **Push-to-Talk**: Hold Option+Space to record, release to transcribe
- **Local Processing**: Uses whisper.cpp with the base.en model (ggml-base.en.bin)
- **Fast Transcription**: 3-5 seconds on Apple Silicon with Core ML
- **Dual-Engine Racing**: Races SFSpeech and Whisper for optimal speed and accuracy
- **Text Injection**: Automatically pastes transcribed text into the active app

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon recommended for best performance

## Building

### Quick Start (Development)

```bash
# Build debug version
swift build

# Run
.build/debug/VoiceType
```

### Build Release App for Applications Folder

#### Option 1: Using Xcode (Recommended)

1. Open the project in Xcode:
   ```bash
   open Package.swift
   ```

2. In Xcode:
   - Select **Product → Archive**
   - Once archived, click **Distribute App**
   - Choose **Copy App**
   - Save the app bundle to your desired location
   - Move `VoiceType.app` to `/Applications`

#### Option 2: Manual Build Script

Create a standalone app bundle that can be installed to `/Applications`:

```bash
# Build release version
swift build -c release

# Create app bundle structure
mkdir -p VoiceType.app/Contents/MacOS
mkdir -p VoiceType.app/Contents/Resources

# Copy executable
cp .build/release/VoiceType VoiceType.app/Contents/MacOS/

# Copy Info.plist
cp VoiceType/Info.plist VoiceType.app/Contents/

# Update Info.plist with bundle identifier and version
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string VoiceType" VoiceType.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.voicetype.app" VoiceType.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleName string VoiceType" VoiceType.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1.0.0" VoiceType.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0.0" VoiceType.app/Contents/Info.plist

# Install to Applications
cp -R VoiceType.app /Applications/

# Launch the app
open /Applications/VoiceType.app
```

Or use this one-liner:
```bash
swift build -c release && \
mkdir -p VoiceType.app/Contents/{MacOS,Resources} && \
cp .build/release/VoiceType VoiceType.app/Contents/MacOS/ && \
cp VoiceType/Info.plist VoiceType.app/Contents/ && \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string VoiceType" VoiceType.app/Contents/Info.plist 2>/dev/null && \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.voicetype.app" VoiceType.app/Contents/Info.plist 2>/dev/null && \
/usr/libexec/PlistBuddy -c "Add :CFBundleName string VoiceType" VoiceType.app/Contents/Info.plist 2>/dev/null && \
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1.0.0" VoiceType.app/Contents/Info.plist 2>/dev/null && \
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0.0" VoiceType.app/Contents/Info.plist 2>/dev/null && \
cp -R VoiceType.app /Applications/ && \
echo "✓ VoiceType.app installed to /Applications"
```

## First Run

1. **Grant Microphone Permission**: The app will prompt for microphone access
2. **Grant Accessibility Permission**: Required to paste text into other apps (System Settings → Privacy & Security → Accessibility)
3. **Grant Speech Recognition Permission**: Required for on-device SFSpeech transcription
4. **Install Model**: Download the model from:
   ```
   https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
   ```
   Or use the in-app downloader in Settings → Model → "Install Model"

   To install manually, place it at:
   ```
   ~/Library/Application Support/VoiceType/Models/ggml-base.en.bin
   ```

## Usage

1. Place your cursor in any text field
2. Hold **Option + Space** (configurable in Settings)
3. Speak
4. Release the keys
5. Transcribed text appears in the text field

## Settings

- **General**:
  - Configure the push-to-talk shortcut
  - Toggle "Launch at Login" to start automatically when you log in
- **Model**:
  - Install or delete the Whisper base.en model
  - View model size and status
  - Download model directly from HuggingFace
- **Permissions**:
  - View and manage microphone, accessibility, and speech recognition permissions
  - Quick links to open System Settings for each permission

## How It Works

### The Transcription Pipeline

VoiceType uses a **dual-engine racing pipeline** for fast and accurate transcription:

```
1. Recording Phase
   └─ AVAudioEngine captures at native sample rate (44.1kHz/48kHz)
      └─ Real-time callbacks feed buffers to both engines

2. Transcription Phase (Concurrent & Async)
   ├─ SFSpeech Runner
   │  └─ Apple's built-in speech recognition
   │     └─ Fast, low-latency response (~1-2s)
   │
   └─ Whisper Runner (Separate Task)
      ├─ AudioResampler converts to 16kHz mono (Whisper requirement)
      └─ Whisper.cpp processes resampled audio
         └─ More accurate, higher quality (~3-5s)

3. Racing Logic
   ├─ First non-empty result wins
   ├─ Immediate text injection into active app
   └─ If SFSpeech wins:
      └─ Whisper continues silently in background
         └─ If result differs, update clipboard with more accurate text
```

### Dual-Engine Architecture

**SFSpeech (Native Recognition)**
- Apple's on-device speech-to-text engine
- Extremely fast (1-2 seconds typically)
- Thread-safe buffer append from audio capture thread
- Returns early partial results as they arrive

**Whisper (ML Model)**
- Local `ggml-base.en.bin` model (can be downloaded in-app or manually installed)
- Higher accuracy than SFSpeech, especially on accented speech and technical words
- Requires audio resampling to 16kHz mono
- Slower but more reliable (3-5 seconds)
- Runs in parallel without blocking the UI
- Supports Core ML acceleration for faster inference on Apple Silicon

### Why Two Engines?

1. **Latency**: SFSpeech provides instant feedback to the user
2. **Accuracy**: Whisper refines results with better accuracy in the background
3. **Redundancy**: If SFSpeech fails or returns empty, Whisper serves as fallback
4. **Clipboard Refinement**: Whisper can silently improve clipboard content if SFSpeech won the race

### Multiprocessing & Concurrency

The pipeline uses Swift's async/await and TaskGroup for true concurrent execution:

- **Audio Capture**: Runs on AVAudioEngine's real-time thread (lock-free buffer append)
- **SFSpeech**: Runs on MainActor with ability to update UI and inject text
- **Whisper**: Runs as a detached Task (separate task hierarchy, no MainActor blocking)
- **Race Condition**: TaskGroup races both engines and returns the first successful result

This design ensures neither engine blocks the other, the UI remains responsive throughout transcription, and audio capture is never interrupted.

## Architecture

```
VoiceType/
├── VoiceTypeApp.swift           # MenuBarExtra entry point
├── Core/
│   └── AppState.swift           # @Observable central state
├── Features/
│   ├── Audio/
│   │   ├── AudioRecorder.swift  # AVAudioEngine capture
│   │   └── AudioResampler.swift # Convert to 16kHz mono
│   ├── Transcription/
│   │   ├── WhisperService.swift # SwiftWhisper wrapper
│   │   ├── SpeechRecognitionService.swift # SFSpeech wrapper
│   │   ├── TranscriptionCoordinator.swift  # Dual-engine pipeline orchestrator
│   │   └── ModelManager.swift   # Download & load models
│   ├── TextOutput/
│   │   └── TextInjector.swift   # Clipboard paste injection
│   └── Hotkey/
│       └── HotkeyManager.swift  # KeyboardShortcuts integration
├── Views/
│   ├── MenuBarView.swift        # Menu dropdown UI
│   ├── StatusIcon.swift         # Dynamic menu bar icon
│   └── SettingsView.swift       # Preferences window
└── Services/
    └── PermissionService.swift  # Mic + Accessibility + Speech Recognition checks
```

## Dependencies

- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) - Swift wrapper for whisper.cpp
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global keyboard shortcuts

## License

MIT
