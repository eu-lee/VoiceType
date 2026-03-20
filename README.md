# VoiceType

A minimal macOS menu bar app for push-to-talk speech transcription using whisper.cpp with Core ML Neural Engine acceleration. Runs 100% locally with no cloud dependencies.

## Features

- **Push-to-Talk**: Hold Option+Space to record, release to transcribe
- **Local Processing**: Uses whisper.cpp with the small.en model — no data leaves your machine
- **GPU Inference**: CoreML Neural Engine acceleration on Apple Silicon for fast transcription
- **Real-Time Feedback**: Live audio level visualization in the menu bar while recording
- **Mic Selection**: Choose your input device from Settings, with persistent selection
- **Text Injection**: Automatically pastes transcribed text into the active app
- **Launch at Login**: Optional auto-start via macOS LaunchAgent
- **Model Management**: Download and manage models directly from the app

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon recommended (Neural Engine acceleration)
- ~500 MB disk space for the Whisper model and CoreML encoder

## Building

### Quick Start (Development)

```bash
# Build debug version
swift build

# Run
.build/debug/VoiceType
```

### Build & Install App

```bash
./scripts/build.sh
```

This builds a release binary, packages it as `VoiceType.app`, signs it with an ad-hoc signature, and installs it to `/Applications`. The app will be searchable in Spotlight.

## First Run

1. **Grant Microphone Permission**: The app will prompt for microphone access
2. **Grant Accessibility Permission**: Required to paste text into other apps (System Settings → Privacy & Security → Accessibility)
3. **Install Model**: Use the in-app downloader in the menu bar dropdown → "Install Model", which downloads both the Whisper model and the CoreML encoder from HuggingFace.

   To install manually, download the model from:
   ```
   https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
   ```
   and place it at:
   ```
   ~/Library/Application Support/VoiceType/Models/ggml-small.en.bin
   ```

## Usage

1. Place your cursor in any text field
2. Hold **Option + Space** (configurable in Settings)
3. Speak
4. Release the keys
5. Transcribed text appears in the text field

## Settings

- **General**: Configure push-to-talk shortcut, select microphone input device, toggle Launch at Login
- **Model**: Install or delete the Whisper small.en model, view model size and status
- **Permissions**: View microphone and accessibility permission status with quick links to System Settings

## How It Works

VoiceType captures audio via AVAudioEngine, resamples to 16kHz mono using the Accelerate framework, and runs whisper.cpp inference with CoreML Neural Engine acceleration. The transcribed text is injected into the active application by briefly placing it on the clipboard and simulating a Cmd+V paste, then restoring the original clipboard contents.

## Architecture

```
VoiceType/
├── VoiceTypeApp.swift                  # MenuBarExtra entry point
├── Core/
│   └── AppState.swift                  # @Observable central state
├── Features/
│   ├── Audio/
│   │   ├── AudioRecorder.swift         # AVAudioEngine capture
│   │   ├── AudioResampler.swift        # Convert to 16kHz mono
│   │   └── AudioDeviceManager.swift    # Input device enumeration
│   ├── Transcription/
│   │   ├── WhisperService.swift        # SwiftWhisper wrapper
│   │   ├── TranscriptionCoordinator.swift  # Pipeline orchestrator
│   │   └── ModelManager.swift          # Download & load models
│   ├── TextOutput/
│   │   └── TextInjector.swift          # Clipboard paste injection
│   └── Hotkey/
│       └── HotkeyManager.swift         # KeyboardShortcuts integration
├── Views/
│   ├── MenuBarView.swift               # Menu dropdown UI
│   ├── StatusIcon.swift                # Dynamic menu bar icon
│   └── SettingsView.swift              # Preferences window (3 tabs)
└── Services/
    └── PermissionService.swift         # Mic + Accessibility checks
```

## Dependencies

- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) — Swift wrapper for whisper.cpp with CoreML support
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global keyboard shortcuts

## License

MIT
