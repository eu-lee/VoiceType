import Foundation
import SwiftUI

/// Represents the current operational status of the app
enum AppStatus: Equatable {
    case idle
    case recording
    case transcribing
    case complete
    case error(String)
}

/// Represents the state of the Whisper model
enum ModelState: Equatable {
    case notDownloaded
    case downloading
    case ready
    case error(String)
}

/// Central observable state for the entire application
@Observable
final class AppState {
    /// Current operational status
    var status: AppStatus = .idle

    /// Current model download/load state
    var modelState: ModelState = .notDownloaded

    /// Current audio input level (0.0 to 1.0) for visual feedback
    var audioLevel: Float = 0.0

    /// Whether microphone permission is granted
    var hasMicrophonePermission: Bool = false

    /// Whether accessibility permission is granted
    var hasAccessibilityPermission: Bool = false


    /// Status message for display
    var statusMessage: String {
        switch status {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .complete:
            return "Done"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    /// Model status message for display
    var modelMessage: String {
        switch modelState {
        case .notDownloaded:
            return "Model not downloaded"
        case .downloading:
            return "Downloading..."
        case .ready:
            return "Model ready"
        case .error(let message):
            return "Model error: \(message)"
        }
    }

    /// Whether the app is ready to record
    var canRecord: Bool {
        hasMicrophonePermission && status == .idle
    }
}
