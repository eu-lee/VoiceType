import AVFoundation
import AppKit
import Speech

/// Handles permission checking and requesting
@Observable
final class PermissionService {
    /// Shared instance
    static let shared = PermissionService()

    /// Current microphone permission status
    var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Whether microphone permission is granted
    var hasMicrophonePermission: Bool {
        microphoneStatus == .authorized
    }

    /// Whether accessibility permission is granted
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Whether speech recognition permission is granted
    var hasSpeechPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    private init() {}

    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        // If already determined, return current status
        if microphoneStatus != .notDetermined {
            return hasMicrophonePermission
        }

        // Request permission
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Request accessibility permission (opens system prompt)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to Accessibility pane
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Open System Settings to Microphone pane
    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    /// Request speech recognition permission
    func requestSpeechPermission() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() != .notDetermined {
            return hasSpeechPermission
        }
        let status = await SpeechRecognitionService.requestAuthorization()
        return status == .authorized
    }

    /// Open System Settings to Speech Recognition pane
    func openSpeechSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
        NSWorkspace.shared.open(url)
    }

    /// Update app state with current permissions
    @MainActor
    func updateAppState(_ appState: AppState) {
        appState.hasMicrophonePermission = hasMicrophonePermission
        appState.hasAccessibilityPermission = hasAccessibilityPermission
        appState.hasSpeechPermission = hasSpeechPermission
    }

    /// Check all permissions and request if needed
    @MainActor
    func checkAndRequestPermissions(appState: AppState) async {
        // Check microphone
        if !hasMicrophonePermission {
            let granted = await requestMicrophonePermission()
            appState.hasMicrophonePermission = granted
        } else {
            appState.hasMicrophonePermission = true
        }

        // Check speech recognition
        if !hasSpeechPermission {
            let granted = await requestSpeechPermission()
            appState.hasSpeechPermission = granted
        } else {
            appState.hasSpeechPermission = true
        }

        // Check accessibility (can only prompt, not auto-grant)
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
        }
        appState.hasAccessibilityPermission = hasAccessibilityPermission
    }
}
