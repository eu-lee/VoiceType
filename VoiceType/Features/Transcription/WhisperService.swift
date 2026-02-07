import Foundation
import SwiftWhisper

/// Wrapper service for SwiftWhisper transcription
final class WhisperService {
    /// Shared instance
    static let shared = WhisperService()

    /// The Whisper instance
    private var whisper: Whisper?

    /// Whether the model is loaded and ready
    var isReady: Bool {
        whisper != nil
    }

    private init() {}

    /// Load the Whisper model
    func loadModel() async throws {
        let modelManager = ModelManager.shared

        guard modelManager.isModelReady else {
            throw WhisperError.modelNotLoaded
        }

        let modelPath = modelManager.modelPath.path

        // Initialize Whisper with the model
        // SwiftWhisper will auto-detect and use Core ML encoder if available
        whisper = try Whisper(fromFileURL: URL(fileURLWithPath: modelPath))

        // Tune params for fast short-dictation inference
        whisper?.params.language = .english
        whisper?.params.single_segment = true
        whisper?.params.temperature_inc = 0
        whisper?.params.no_context = true
    }

    /// Transcribe audio samples
    /// - Parameters:
    ///   - samples: 16kHz mono Float32 audio samples
    ///   - language: Optional language code (e.g., "en"). Currently ignored - SwiftWhisper uses auto-detection.
    /// - Returns: Transcribed text
    func transcribe(_ samples: [Float], language: String? = nil) async throws -> String {
        guard let whisper = whisper else {
            print("[WhisperService] Model not loaded")
            throw WhisperError.modelNotLoaded
        }

        guard !samples.isEmpty else {
            print("[WhisperService] No audio samples to transcribe")
            throw WhisperError.transcriptionFailed
        }

        print("[WhisperService] Transcribing \(samples.count) samples\(language.map { " (language: \($0))" } ?? "")")

        // Transcribe the audio
        // Note: SwiftWhisper will auto-detect language. Language parameter is stored for future use
        // when SwiftWhisper supports explicit language specification.
        let segments = try await whisper.transcribe(audioFrames: samples)

        print("[WhisperService] Got \(segments.count) segments")

        // Combine all segments into final text
        let rawText = segments.map { $0.text }.joined(separator: " ")

        // Clean up the text (remove leading/trailing whitespace, normalize spaces)
        let trimmed = rawText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let finalText = trimmed.replacingOccurrences(of: "  ", with: " ")

        print("[WhisperService] Transcription result: \(finalText)")
        return finalText
    }

    /// Unload the model to free memory
    func unloadModel() {
        whisper = nil
    }
}

enum WhisperError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded"
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        }
    }
}
