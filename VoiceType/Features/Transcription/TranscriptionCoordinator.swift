import Foundation
import AppKit

/// Orchestrates the full pipeline: record → resample → whisper → output
@Observable
@MainActor
final class TranscriptionCoordinator {
    /// Shared instance
    static let shared = TranscriptionCoordinator()

    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService.shared
    private let textInjector = TextInjector()

    /// Reference to app state
    var appState: AppState?

    private init() {
        // Set up audio level callback
        audioRecorder.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                self?.appState?.audioLevel = level
            }
        }
    }

    /// Initialize the coordinator with app state
    func configure(with appState: AppState) {
        self.appState = appState
    }

    /// Start the recording phase
    func startRecording() {
        guard let appState = appState else { return }
        guard appState.canRecord else { return }

        do {
            // Set the user's preferred input device before starting
            try audioRecorder.setInputDevice(AudioDeviceManager.shared.selectedDeviceID)

            try audioRecorder.startRecording()
            appState.status = .recording
        } catch {
            appState.status = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Stop recording and transcribe with Whisper
    func stopRecordingAndTranscribe() {
        guard let appState = appState else { return }
        guard appState.status == .recording else { return }

        let samples = audioRecorder.stopRecording()
        let inputSampleRate = audioRecorder.inputSampleRate
        appState.audioLevel = 0.0
        appState.status = .transcribing

        guard whisperService.isReady, !samples.isEmpty else {
            appState.status = .error(samples.isEmpty ? "No audio recorded" : "Model not loaded")
            resetToIdleAfterDelay()
            return
        }

        Task {
            let text = await Task.detached { [whisperService] in
                let resampledSamples = AudioResampler.resampleWithConverter(
                    samples, from: inputSampleRate
                ) ?? AudioResampler.resample(samples, from: inputSampleRate)

                guard !resampledSamples.isEmpty else { return "" }

                do {
                    return try await whisperService.transcribe(resampledSamples)
                } catch {
                    print("[TranscriptionCoordinator] Whisper failed: \(error.localizedDescription)")
                    return ""
                }
            }.value

            if !text.isEmpty {
                textInjector.injectText(text)
                appState.status = .complete
                print("[TranscriptionCoordinator] Transcribed: \(text)")
            } else {
                appState.status = .error("No speech detected")
            }

            resetToIdleAfterDelay()
        }
    }

    /// Reset to idle after a brief delay
    private func resetToIdleAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            if case .complete = appState?.status {
                appState?.status = .idle
            } else if case .error = appState?.status {
                appState?.status = .idle
            }
        }
    }

    /// Load the Whisper model
    func loadModel() async {
        guard let appState = appState else { return }

        do {
            try await whisperService.loadModel()
            appState.modelState = .ready
        } catch {
            appState.modelState = .error(error.localizedDescription)
        }
    }

    /// Download and load the model
    func downloadAndLoadModel() async {
        guard let appState = appState else { return }

        let modelManager = ModelManager.shared

        // Download if needed
        if !modelManager.isModelReady {
            appState.modelState = .downloading

            do {
                try await modelManager.downloadModel()
            } catch {
                appState.modelState = .error(error.localizedDescription)
                return
            }
        }

        // Load the model
        await loadModel()
    }
}
