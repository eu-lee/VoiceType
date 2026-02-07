import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The push-to-talk hotkey
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: .option))
}

/// Manages the push-to-talk hotkey
@Observable
@MainActor
final class HotkeyManager {
    /// Shared instance
    static let shared = HotkeyManager()

    /// Reference to the transcription coordinator
    private var coordinator: TranscriptionCoordinator?

    /// Whether the hotkey is currently held down
    private(set) var isHotkeyPressed = false

    private init() {}

    /// Configure the hotkey manager
    func configure(with coordinator: TranscriptionCoordinator) {
        self.coordinator = coordinator
        setupHotkey()
    }

    /// Set up the hotkey listeners
    private func setupHotkey() {
        // Key down - start recording
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                guard !self.isHotkeyPressed else { return }
                self.isHotkeyPressed = true
                self.coordinator?.startRecording()
            }
        }

        // Key up - stop recording and transcribe
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.isHotkeyPressed else { return }
                self.isHotkeyPressed = false
                self.coordinator?.stopRecordingAndTranscribe()
            }
        }
    }

    /// Disable the hotkey
    func disable() {
        KeyboardShortcuts.disable(.pushToTalk)
    }

    /// Re-enable the hotkey
    func enable() {
        setupHotkey()
    }
}
