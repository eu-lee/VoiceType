import AVFoundation
import Accelerate

/// Resamples audio to 16kHz mono Float32 format required by Whisper
struct AudioResampler {
    /// Target sample rate for Whisper
    static let targetSampleRate: Double = 16000.0

    /// Resample audio from source sample rate to 16kHz
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - sourceSampleRate: Sample rate of input audio
    /// - Returns: Resampled audio at 16kHz
    static func resample(_ samples: [Float], from sourceSampleRate: Double) -> [Float] {
        guard sourceSampleRate != targetSampleRate else {
            return samples
        }

        guard !samples.isEmpty else {
            print("[AudioResampler] WARNING: Linear interpolation called with empty samples")
            return []
        }

        let ratio = targetSampleRate / sourceSampleRate
        let outputLength = Int(Double(samples.count) * ratio)

        guard outputLength > 0 else {
            print("[AudioResampler] WARNING: Linear interpolation would produce empty output")
            return []
        }

        var output = [Float](repeating: 0, count: outputLength)

        // Use vDSP for high-quality resampling
        var sourceIndex: Double = 0
        let step = sourceSampleRate / targetSampleRate

        for i in 0..<outputLength {
            let index = Int(sourceIndex)
            let fraction = Float(sourceIndex - Double(index))

            if index + 1 < samples.count {
                // Linear interpolation
                output[i] = samples[index] * (1 - fraction) + samples[index + 1] * fraction
            } else if index < samples.count {
                output[i] = samples[index]
            }

            sourceIndex += step
        }

        return output
    }

    /// Resample using AVAudioConverter for higher quality
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - sourceSampleRate: Sample rate of input audio
    /// - Returns: Resampled audio at 16kHz, or nil on failure
    static func resampleWithConverter(_ samples: [Float], from sourceSampleRate: Double) -> [Float]? {
        guard sourceSampleRate != targetSampleRate else {
            return samples
        }

        guard !samples.isEmpty else {
            print("[AudioResampler] ERROR: No input samples to resample")
            return nil
        }

        // Create source format
        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("[AudioResampler] ERROR: Failed to create source format")
            return nil
        }

        // Create target format
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("[AudioResampler] ERROR: Failed to create target format")
            return nil
        }

        // Create converter
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            print("[AudioResampler] ERROR: Failed to create audio converter")
            return nil
        }

        // Create source buffer
        let frameCount = AVAudioFrameCount(samples.count)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            print("[AudioResampler] ERROR: Failed to allocate source buffer")
            return nil
        }
        sourceBuffer.frameLength = frameCount

        // Copy samples to source buffer
        if let channelData = sourceBuffer.floatChannelData {
            samples.withUnsafeBufferPointer { ptr in
                channelData[0].update(from: ptr.baseAddress!, count: samples.count)
            }
        }

        // Calculate output frame count
        let ratio = targetSampleRate / sourceSampleRate
        let outputFrameCount = AVAudioFrameCount(Double(samples.count) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            print("[AudioResampler] ERROR: Failed to allocate output buffer")
            return nil
        }

        // Perform conversion
        var error: NSError?
        var inputConsumed = false

        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        guard status != .error, error == nil else {
            print("[AudioResampler] ERROR: Conversion failed - status: \(status), error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }

        guard outputBuffer.frameLength > 0 else {
            print("[AudioResampler] ERROR: Output buffer has no frames")
            return nil
        }

        // Extract output samples
        guard let outputChannelData = outputBuffer.floatChannelData else {
            print("[AudioResampler] ERROR: Failed to get output channel data")
            return nil
        }

        let outputSamples = Array(UnsafeBufferPointer(
            start: outputChannelData[0],
            count: Int(outputBuffer.frameLength)
        ))

        return outputSamples
    }
}
