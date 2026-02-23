import Foundation

/// Manages Whisper model downloads and storage
@Observable
final class ModelManager {
    /// Shared instance
    static let shared = ModelManager()

    /// Model file name
    private let modelFileName = "ggml-small.en.bin"

    /// Core ML encoder file name
    private let coreMLEncoderName = "ggml-small.en-encoder.mlmodelc"

    /// HuggingFace base URL for models
    private let huggingFaceBaseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    /// Whether download is in progress
    var isDownloading = false

    /// Error message if any
    var errorMessage: String?

    /// Application support directory for models
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("VoiceType/Models", isDirectory: true)
    }

    /// Full path to the model file
    var modelPath: URL {
        modelsDirectory.appendingPathComponent(modelFileName)
    }

    /// Full path to the Core ML encoder
    var coreMLEncoderPath: URL {
        modelsDirectory.appendingPathComponent(coreMLEncoderName)
    }

    /// Whether the model is downloaded and ready
    var isModelReady: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// Whether the Core ML encoder is available
    var hasCoreMLEncoder: Bool {
        FileManager.default.fileExists(atPath: coreMLEncoderPath.path)
    }

    private init() {
        createModelsDirectoryIfNeeded()
    }

    /// Create models directory if it doesn't exist
    private func createModelsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    /// Download the Whisper model and CoreML encoder
    func downloadModel() async throws {
        guard !isDownloading else { return }

        await MainActor.run {
            isDownloading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isDownloading = false
            }
        }

        // Download main model
        let modelURL = URL(string: "\(huggingFaceBaseURL)/\(modelFileName)")!
        try await downloadFile(from: modelURL, to: modelPath)

        // Download pre-compiled Core ML encoder for Neural Engine acceleration
        if !hasCoreMLEncoder {
            let encoderZipName = "\(coreMLEncoderName).zip"
            let encoderURL = URL(string: "\(huggingFaceBaseURL)/\(encoderZipName)")!
            let zipDestination = modelsDirectory.appendingPathComponent(encoderZipName)

            do {
                try await downloadFile(from: encoderURL, to: zipDestination)
                try unzipCoreMLEncoder(from: zipDestination)
                try? FileManager.default.removeItem(at: zipDestination)
                print("[ModelManager] CoreML encoder installed")
            } catch {
                try? FileManager.default.removeItem(at: zipDestination)
                print("[ModelManager] CoreML encoder download failed (non-fatal): \(error.localizedDescription)")
            }
        }
    }

    /// Unzip the CoreML encoder bundle
    private func unzipCoreMLEncoder(from zipURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", modelsDirectory.path]
        process.standardOutput = nil
        process.standardError = nil
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModelError.downloadFailed
        }
    }

    /// Download a file
    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelError.downloadFailed
        }

        // Remove existing file if present, then move temp file to destination
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    /// Delete downloaded model
    func deleteModel() throws {
        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
        }
        if FileManager.default.fileExists(atPath: coreMLEncoderPath.path) {
            try FileManager.default.removeItem(at: coreMLEncoderPath)
        }
    }

    /// Get model file size in bytes
    var modelFileSize: Int64? {
        guard isModelReady else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path)
        return attributes?[.size] as? Int64
    }

    /// Format file size for display
    var formattedModelSize: String {
        guard let size = modelFileSize else { return "Not downloaded" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

enum ModelError: LocalizedError {
    case downloadFailed
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to load model. Please ensure ggml-small.en.bin is placed in ~/Library/Application Support/VoiceType/Models/"
        case .modelNotFound:
            return "Model file not found. Please download ggml-small.en.bin from https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin and place it in ~/Library/Application Support/VoiceType/Models/"
        }
    }
}
