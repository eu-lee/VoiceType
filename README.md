# VoiceType

A minimal macOS menu bar app for push-to-talk speech transcription using whisper.cpp with Core ML acceleration. Runs 100% locally with no cloud dependencies.

## Features

- **Push-to-Talk**: Hold Option+Space to record, release to transcribe
- **Local Processing**: Uses whisper.cpp with the small.en model (~460MB)
- **Fast Transcription**: 3-5 seconds on Apple Silicon with Core ML
- **Text Injection**: Automatically pastes transcribed text into the active app

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon recommended for best performance

- 
## Building

```bash
# Clone and build
swift build

# Run
.build/debug/VoiceType
```

Or open in Xcode:
```bash
open Package.swift
```

## First Run

1. **Grant Microphone Permission**: The app will prompt for microphone access
2. **Grant Accessibility Permission**: Required to paste text into other apps (System Settings → Privacy & Security → Accessibility)
3. **Download Model**: Click "Download Model" in the menu to download the Whisper small.en model (~460MB)

## Usage

1. Place your cursor in any text field
2. Hold **Option + Space** (configurable in Settings)
3. Speak
4. Release the keys
5. Transcribed text appears in the text field

## Settings

- **Hotkey**: Configure the push-to-talk shortcut
- **Launch at Login**: Start automatically when you log in
- **Model Management**: Download or delete the Whisper model

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
│   │   ├── TranscriptionCoordinator.swift  # Pipeline orchestrator
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
    └── PermissionService.swift  # Mic + Accessibility checks
```

## Dependencies

- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) - Swift wrapper for whisper.cpp
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global keyboard shortcuts

## License

MIT
