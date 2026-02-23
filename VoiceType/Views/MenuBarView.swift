import SwiftUI
import KeyboardShortcuts

/// Main menu bar dropdown view
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @State private var coordinator = TranscriptionCoordinator.shared
    @State private var hotkeyManager = HotkeyManager.shared
    @State private var permissionService = PermissionService.shared
    @State private var deviceManager = AudioDeviceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status section
            statusSection

            Divider()

            // Permissions section (if needed)
            if !appState.hasMicrophonePermission || !appState.hasAccessibilityPermission {
                permissionsSection
                Divider()
            }

            // Model section
            modelSection

            Divider()

            // Actions
            actionsSection
        }
        .padding()
        .frame(width: 280)
        .task {
            await initialize()
        }
        .onAppear {
            // Refresh permissions every time menu opens
            permissionService.updateAppState(appState)
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.statusMessage)
                    .font(.headline)

                if appState.status == .recording {
                    AudioLevelIndicator(level: appState.audioLevel)
                        .frame(height: 4)
                }
            }

            Spacer()
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions Required")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !appState.hasMicrophonePermission {
                Button {
                    permissionService.openMicrophoneSettings()
                } label: {
                    Label("Grant Microphone Access", systemImage: "mic.slash")
                }
            }

            if !appState.hasAccessibilityPermission {
                Button {
                    permissionService.openAccessibilitySettings()
                } label: {
                    Label("Grant Accessibility Access", systemImage: "accessibility")
                }
            }

        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Model")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(appState.modelMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .downloading = appState.modelState {
                ProgressView()
                    .controlSize(.small)
            }

            if case .notDownloaded = appState.modelState {
                Button("Install Model") {
                    Task {
                        await coordinator.downloadAndLoadModel()
                    }
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

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hotkey:")
                    .foregroundStyle(.secondary)
                KeyboardShortcuts.Recorder(for: .pushToTalk)
            }

            Picker(selection: $deviceManager.selectedDeviceUID) {
                Text("System Default")
                    .tag(nil as String?)
                ForEach(deviceManager.inputDevices) { device in
                    Text(device.name)
                        .tag(device.uid as String?)
                }
            } label: {
                Label("Mic:", systemImage: "mic")
                    .foregroundStyle(.secondary)
            }

            HStack {
                SettingsLink {
                    Text("Settings...")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch appState.status {
        case .idle:
            return "waveform"
        case .recording:
            return "waveform.circle.fill"
        case .transcribing:
            return "ellipsis.circle"
        case .complete:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle:
            return .secondary
        case .recording:
            return .red
        case .transcribing:
            return .orange
        case .complete:
            return .green
        case .error:
            return .red
        }
    }

    private func initialize() async {
        // Configure coordinator
        coordinator.configure(with: appState)
        hotkeyManager.configure(with: coordinator)

        // Check permissions
        await permissionService.checkAndRequestPermissions(appState: appState)

        // Load model if already downloaded
        if ModelManager.shared.isModelReady {
            await coordinator.loadModel()
        }
    }
}

/// Audio level indicator bar
struct AudioLevelIndicator: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.quaternary)

                Rectangle()
                    .fill(.green)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
            .cornerRadius(2)
        }
    }
}
