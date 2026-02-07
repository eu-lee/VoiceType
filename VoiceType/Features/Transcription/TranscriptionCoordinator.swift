import Foundation
import AppKit

/// Orchestrates the full pipeline: record → transcribe → output
@Observable
@MainActor
final class TranscriptionCoordinator {
    /// Shared instance
    static let shared = TranscriptionCoordinator()

    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService.shared
    private let speechService = SpeechRecognitionService.shared
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

        // Wire audio buffers to speech recognition service
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            self?.speechService.appendBuffer(buffer)
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
            // Start speech recognition first so it's ready when audio flows
            speechService.startSession()

            try audioRecorder.startRecording()
            appState.status = .recording
        } catch {
            speechService.cleanup()
            appState.status = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Stop recording and begin transcription — races SFSpeech and Whisper in parallel
    func stopRecordingAndTranscribe() {
        guard let appState = appState else { return }
        guard appState.status == .recording else { return }

        // Stop recording and get samples for Whisper
        let samples = audioRecorder.stopRecording()
        let inputSampleRate = audioRecorder.inputSampleRate
        appState.audioLevel = 0.0
        appState.status = .transcribing

        Task {
            // Launch both engines as detached tasks so they run concurrently
            let speechTask = Task<String, Never> {
                await speechService.finishAndWait()
            }

            let whisperReady = whisperService.isReady && !samples.isEmpty
            let whisperTask: Task<String, Never>? = if whisperReady {
                Task.detached { [whisperService] in
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
                }
            } else {
                nil
            }

            // Race both engines: first non-empty result wins
            enum Engine: Sendable { case speech, whisper }
            typealias Result = (engine: Engine, text: String)

            let winner: Result? = await withTaskGroup(of: Result?.self) { group in
                group.addTask {
                    let text = await speechTask.value
                    return text.isEmpty ? nil : (.speech, text)
                }

                if let wTask = whisperTask {
                    group.addTask {
                        let text = await wTask.value
                        return text.isEmpty ? nil : (.whisper, text)
                    }
                }

                // Return first non-nil result
                for await result in group {
                    if let result { return result }
                }
                return nil
            }

            if let winner {
                textInjector.injectText(winner.text)
                appState.status = .complete
                print("[TranscriptionCoordinator] \(winner.engine) won the race: \(winner.text)")

                // If SFSpeech won, let Whisper finish for clipboard refinement
                if winner.engine == .speech, let wTask = whisperTask {
                    let sfText = winner.text
                    Task {
                        let whisperText = await wTask.value
                        guard !whisperText.isEmpty else { return }

                        let normalizedSF = sfText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let normalizedWhisper = whisperText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                        if normalizedWhisper != normalizedSF {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(whisperText, forType: .string)
                            print("[TranscriptionCoordinator] Whisper refinement on clipboard: \(whisperText)")
                        } else {
                            print("[TranscriptionCoordinator] Whisper matches SFSpeech, no refinement needed")
                        }
                    }
                }

                resetToIdleAfterDelay()
            } else if samples.isEmpty {
                appState.status = .error("No audio recorded")
                resetToIdleAfterDelay()
            } else {
                appState.status = .error("No speech detected")
                resetToIdleAfterDelay()
            }
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
            appState.modelState = .downloading(progress: 0)

            // Observe download progress
            let progressTask = Task {
                while modelManager.isDownloading {
                    appState.modelState = .downloading(progress: modelManager.downloadProgress)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            do {
                try await modelManager.downloadModel()
                progressTask.cancel()
            } catch {
                progressTask.cancel()
                appState.modelState = .error(error.localizedDescription)
                return
            }
        }

        // Load the model
        await loadModel()
    }
}
