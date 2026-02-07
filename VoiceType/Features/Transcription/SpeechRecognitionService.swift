import Foundation
import Speech
import AVFoundation

/// Wraps SFSpeechRecognizer for streaming on-device speech recognition
@MainActor
final class SpeechRecognitionService {
    static let shared = SpeechRecognitionService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscription: String = ""
    private var finalContinuation: CheckedContinuation<String, Never>?

    /// Non-isolated reference for appending buffers from the audio thread.
    /// Only written on MainActor (in startSession/stopSession), read from audio thread.
    /// Safe because SFSpeechAudioBufferRecognitionRequest.append is thread-safe.
    nonisolated(unsafe) private var activeRequest: SFSpeechAudioBufferRecognitionRequest?

    private init() {}

    /// Request speech recognition authorization
    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Whether speech recognition authorization is granted
    static var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Start a new recognition session
    func startSession() {
        // Clean up any existing session
        cleanup()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        recognitionRequest = request
        activeRequest = request
        latestTranscription = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result = result {
                    self.latestTranscription = result.bestTranscription.formattedString
                    // If this is the final result, resolve the waiter
                    if result.isFinal {
                        self.finalContinuation?.resume(returning: self.latestTranscription)
                        self.finalContinuation = nil
                    }
                }
                if error != nil, self.finalContinuation != nil {
                    // Error means no more results coming — resolve with whatever we have
                    self.finalContinuation?.resume(returning: self.latestTranscription)
                    self.finalContinuation = nil
                }
            }
        }
    }

    /// Append an audio buffer to the recognition request.
    /// Called from AVAudioEngine's real-time thread.
    nonisolated func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        // SFSpeechAudioBufferRecognitionRequest.append is thread-safe
        activeRequest?.append(buffer)
    }

    /// Signal end of audio and wait for SFSpeech to deliver its final result.
    /// Returns the transcription text (may be empty if nothing was recognized).
    func finishAndWait() async -> String {
        activeRequest = nil
        recognitionRequest?.endAudio()

        // If we already have no task, return what we have
        guard recognitionTask != nil else { return latestTranscription }

        // Wait for the final result callback, with a timeout
        let text = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            self.finalContinuation = continuation

            // Timeout after 1.5s — return whatever we have
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                if let pending = self.finalContinuation {
                    pending.resume(returning: self.latestTranscription)
                    self.finalContinuation = nil
                }
            }
        }

        cleanup()
        return text
    }

    /// Clean up session state
    func cleanup() {
        activeRequest = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        // Don't nil out finalContinuation here — it's managed by finishAndWait
    }
}
