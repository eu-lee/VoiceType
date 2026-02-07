import SwiftUI

/// Dynamic menu bar icon that reflects current app state
struct StatusIcon: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .symbolEffect(.variableColor.iterative, isActive: isAnimating)
    }

    private var iconName: String {
        switch appState.status {
        case .idle:
            return "quote.bubble.fill"
        case .recording, .transcribing:
            return "waveform"
        case .complete:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var isAnimating: Bool {
        appState.status == .recording || appState.status == .transcribing
    }
}
