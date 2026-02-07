import SwiftUI
import KeyboardShortcuts

@main
struct VoiceTypeApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            StatusIcon()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
                .onAppear {
                    // Bring settings window to front after a brief delay to ensure it's created
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let settingsWindow = NSApplication.shared.windows.first(where: { !$0.isVisible || $0.level == .normal }) {
                            settingsWindow.level = .floating
                            settingsWindow.makeKeyAndOrderFront(nil)
                        }
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
