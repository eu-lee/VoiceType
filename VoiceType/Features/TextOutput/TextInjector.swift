import AppKit
import Carbon.HIToolbox

/// Injects transcribed text into the active application
final class TextInjector {
    /// Inject text by copying to clipboard and simulating Cmd+V
    func injectText(_ text: String) {
        // Save current clipboard contents
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set transcribed text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            // Simulate Cmd+V
            self?.simulatePaste()

            // Restore previous clipboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    /// Simulate Cmd+V keystroke
    private func simulatePaste() {
        // Create key down event for 'V' with Command modifier
        let keyCode = CGKeyCode(kVK_ANSI_V)

        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            return
        }
        keyDownEvent.flags = .maskCommand

        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyUpEvent.flags = .maskCommand

        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }

    /// Check if accessibility permissions are granted
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt user to grant accessibility permissions
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
