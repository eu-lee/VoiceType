import AVFoundation
import AppKit

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

    /// Update app state with current permissions
    @MainActor
    func updateAppState(_ appState: AppState) {
        appState.hasMicrophonePermission = hasMicrophonePermission
        appState.hasAccessibilityPermission = hasAccessibilityPermission
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

        // Check accessibility (can only prompt, not auto-grant)
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
        }
        appState.hasAccessibilityPermission = hasAccessibilityPermission
    }
}
