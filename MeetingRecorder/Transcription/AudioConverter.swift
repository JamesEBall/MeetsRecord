@preconcurrency import AVFAudio
import os

/// Converts audio files to 16kHz mono Float32 format required by Whisper.
struct AudioConverter {
    private static let logger = Logger(subsystem: "MeetingRecorder", category: "AudioConverter")

    /// Reads a CAF/WAV file and returns 16kHz mono Float32 samples.
    static func convertTo16kHzMono(fileURL: URL) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: fileURL)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.audioConversionFailed
        }

        guard let converter = AVAudioConverter(
            from: inputFile.processingFormat,
            to: targetFormat
        ) else {
            throw RecorderError.audioConversionFailed
        }

        let ratio = 16_000.0 / inputFile.processingFormat.sampleRate
        let estimatedOutputFrames = AVAudioFrameCount(Double(inputFile.length) * ratio) + 1024

        // Process in chunks to avoid loading entire file into memory
        let inputChunkSize: AVAudioFrameCount = 16384
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFile.processingFormat,
            frameCapacity: inputChunkSize
        ) else {
            throw RecorderError.audioConversionFailed
        }

        var allSamples: [Float] = []
        allSamples.reserveCapacity(Int(estimatedOutputFrames))

        let outputChunkCapacity = AVAudioFrameCount(Double(inputChunkSize) * ratio) + 256
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputChunkCapacity
        ) else {
            throw RecorderError.audioConversionFailed
        }

        logger.info("Converting \(inputFile.length) frames from \(inputFile.processingFormat.sampleRate)Hz to 16kHz mono")

        while inputFile.framePosition < inputFile.length {
            // Read a chunk from the input file
            do {
                try inputFile.read(into: inputBuffer)
            } catch {
                logger.warning("Read error at frame \(inputFile.framePosition): \(error.localizedDescription)")
                break
            }

            if inputBuffer.frameLength == 0 { break }

            // Convert the chunk
            var convError: NSError?
            var consumed = false
            outputBuffer.frameLength = 0

            converter.convert(to: outputBuffer, error: &convError) { _, outStatus in
                if consumed {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if let err = convError {
                logger.error("Conversion error: \(err.localizedDescription)")
                throw err
            }

            // Append converted samples
            if let channelData = outputBuffer.floatChannelData, outputBuffer.frameLength > 0 {
                let ptr = UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength))
                allSamples.append(contentsOf: ptr)
            }
        }

        logger.info("Conversion complete: \(allSamples.count) samples at 16kHz")
        return allSamples
    }
}
