import AVFoundation
import CoreAudio
import Foundation

/// Handles microphone audio capture using AVAudioEngine
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    /// Callback for audio level updates (0.0 to 1.0)
    var onAudioLevel: ((Float) -> Void)?

    /// Callback for raw audio buffers (called from real-time audio thread)
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// Whether currently recording
    private(set) var isRecording = false

    /// Set the input device on the engine's input node.
    /// Pass nil to use the system default.
    func setInputDevice(_ deviceID: AudioDeviceID?) throws {
        let inputNode = engine.inputNode
        let audioUnit = inputNode.audioUnit!

        if let deviceID {
            var devID = deviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &devID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            guard status == noErr else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to set input device (OSStatus \(status))"]
                )
            }
        }
        // When nil, AVAudioEngine uses system default — no action needed
    }

    /// Start recording from the microphone
    func startRecording() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Clear previous buffer
        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()

        // Install tap on input node to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stop recording and return the captured audio samples
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        return samples
    }

    /// Get current audio samples without stopping recording (for live preview)
    func getCurrentSamples() -> [Float] {
        bufferLock.lock()
        let samples = audioBuffer
        bufferLock.unlock()
        return samples
    }

    /// Process incoming audio buffer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Forward raw buffer to speech recognition before any processing
        onAudioBuffer?(buffer)

        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // Convert to mono if stereo
        var monoSamples = [Float](repeating: 0, count: frameLength)

        if channelCount == 1 {
            monoSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            // Average channels for mono
            for frame in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][frame]
                }
                monoSamples[frame] = sum / Float(channelCount)
            }
        }

        // Calculate audio level (RMS)
        let rms = sqrt(monoSamples.reduce(0) { $0 + $1 * $1 } / Float(frameLength))
        let level = min(1.0, rms * 10) // Scale for visibility

        DispatchQueue.main.async { [weak self] in
            self?.onAudioLevel?(level)
        }

        // Append to buffer
        bufferLock.lock()
        audioBuffer.append(contentsOf: monoSamples)
        bufferLock.unlock()
    }

    /// Get the sample rate of the input device
    var inputSampleRate: Double {
        engine.inputNode.outputFormat(forBus: 0).sampleRate
    }
}
