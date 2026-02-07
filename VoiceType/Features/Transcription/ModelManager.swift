import Foundation

/// Manages Whisper model downloads and storage
@Observable
final class ModelManager {
    /// Shared instance
    static let shared = ModelManager()

    /// Model file name
    private let modelFileName = "ggml-tiny.en.bin"

    /// Core ML encoder file name
    private let coreMLEncoderName = "ggml-tiny.en-encoder.mlmodelc"

    /// HuggingFace base URL for models
    private let huggingFaceBaseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    /// Current download progress (0.0 to 1.0)
    var downloadProgress: Double = 0.0

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

    /// Download the Whisper model
    func downloadModel() async throws {
        guard !isDownloading else { return }

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
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

        // Try to download Core ML encoder (optional, may not be available)
        // Note: Core ML models need to be compiled, so we skip this for now
        // Users can manually add compiled Core ML models if desired
    }

    /// Download a file with progress reporting
    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelError.downloadFailed
        }

        let expectedLength = response.expectedContentLength
        var receivedLength: Int64 = 0
        var data = Data()
        data.reserveCapacity(Int(expectedLength))

        for try await byte in asyncBytes {
            data.append(byte)
            receivedLength += 1

            if expectedLength > 0 {
                let progress = Double(receivedLength) / Double(expectedLength)
                await MainActor.run {
                    self.downloadProgress = progress
                }
            }
        }

        try data.write(to: destination)
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
            return "Failed to load model. Please ensure ggml-tiny.en.bin is placed in ~/Library/Application Support/VoiceType/Models/"
        case .modelNotFound:
            return "Model file not found. Please download ggml-tiny.en.bin from https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin and place it in ~/Library/Application Support/VoiceType/Models/"
        }
    }
}
