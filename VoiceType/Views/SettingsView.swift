import SwiftUI
import KeyboardShortcuts
import ServiceManagement

/// Settings window with tabs
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ModelSettingsView()
                .tabItem {
                    Label("Model", systemImage: "brain")
                }

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 450, height: 300)
    }
}

/// General settings tab
struct GeneralSettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Push-to-Talk Hotkey")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .pushToTalk)
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section {
                Text("Hold the hotkey to record, release to transcribe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Transcribed text will be pasted into the active app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

/// Model settings tab
struct ModelSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var modelManager = ModelManager.shared
    @State private var coordinator = TranscriptionCoordinator.shared
    @State private var isDeleting = false

    var body: some View {
        Form {
            Section("Whisper Model") {
                HStack {
                    Text("Model")
                    Spacer()
                    Text("small.en")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Size")
                    Spacer()
                    Text(modelManager.formattedModelSize)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text(appState.modelMessage)
                        .foregroundStyle(modelStatusColor)
                }

                if case .downloading(let progress) = appState.modelState {
                    ProgressView(value: progress) {
                        Text("Downloading...")
                    }
                }
            }

            Section {
                if case .notDownloaded = appState.modelState {
                    Button("Download Model") {
                        Task {
                            await coordinator.downloadAndLoadModel()
                        }
                    }
                }

                if case .ready = appState.modelState {
                    Button("Delete Model", role: .destructive) {
                        isDeleting = true
                    }
                }

                if case .error = appState.modelState {
                    Button("Retry Download") {
                        Task {
                            await coordinator.downloadAndLoadModel()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Delete Model?", isPresented: $isDeleting) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteModel()
            }
        } message: {
            Text("You will need to download the model again to use VoiceType.")
        }
    }

    private var modelStatusColor: Color {
        switch appState.modelState {
        case .ready:
            return .green
        case .error:
            return .red
        default:
            return .secondary
        }
    }

    private func deleteModel() {
        do {
            try modelManager.deleteModel()
            appState.modelState = .notDownloaded
        } catch {
            appState.modelState = .error(error.localizedDescription)
        }
    }
}

/// Permissions settings tab
struct PermissionsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var permissionService = PermissionService.shared

    var body: some View {
        Form {
            Section("Required Permissions") {
                HStack {
                    Image(systemName: appState.hasMicrophonePermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(appState.hasMicrophonePermission ? .green : .red)

                    Text("Microphone")

                    Spacer()

                    if !appState.hasMicrophonePermission {
                        Button("Open Settings") {
                            permissionService.openMicrophoneSettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Image(systemName: appState.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(appState.hasAccessibilityPermission ? .green : .red)

                    Text("Accessibility")

                    Spacer()

                    if !appState.hasAccessibilityPermission {
                        Button("Open Settings") {
                            permissionService.openAccessibilitySettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Image(systemName: appState.hasSpeechPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(appState.hasSpeechPermission ? .green : .red)

                    Text("Speech Recognition")

                    Spacer()

                    if !appState.hasSpeechPermission {
                        Button("Open Settings") {
                            permissionService.openSpeechSettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Microphone access is required to record your voice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Accessibility access is required to paste text into other apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Speech recognition is used for instant on-device transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Refresh Permissions") {
                    permissionService.updateAppState(appState)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
