@preconcurrency import AVFAudio
import CoreMedia
import os

/// Receives system audio and microphone CMSampleBuffers from ScreenCaptureKit,
/// converts them to PCM format, and writes them to the AudioFileWriter.
/// Thread-safe: called from separate dispatch queues for system and mic audio.
/// Marked @unchecked Sendable because all mutable state is protected by NSLock.
final class AudioMixer: @unchecked Sendable {
    private let outputFormat: AVAudioFormat
    private let writer: AudioFileWriter
    private let lock = NSLock()
    private let logger = Logger(subsystem: "MeetsRecord", category: "AudioMixer")

    var isPaused = false

    private var systemAudioConverter: AVAudioConverter?
    private var micAudioConverter: AVAudioConverter?

    init(outputFormat: AVAudioFormat, writer: AudioFileWriter) {
        self.outputFormat = outputFormat
        self.writer = writer
    }

    func appendSystemAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused else { return }
        guard let pcmBuffer = Self.pcmBuffer(from: sampleBuffer) else { return }

        let converted = convertIfNeeded(buffer: pcmBuffer, converter: &systemAudioConverter)
        lock.lock()
        writer.write(buffer: converted)
        lock.unlock()
    }

    func appendMicrophoneBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused else { return }
        guard let pcmBuffer = Self.pcmBuffer(from: sampleBuffer) else { return }

        let converted = convertIfNeeded(buffer: pcmBuffer, converter: &micAudioConverter)
        lock.lock()
        writer.write(buffer: converted)
        lock.unlock()
    }

    func flush() {
        lock.lock()
        // Ensure any pending state is clean
        lock.unlock()
    }

    // MARK: - Format Conversion

    private func convertIfNeeded(
        buffer: AVAudioPCMBuffer,
        converter: inout AVAudioConverter?
    ) -> AVAudioPCMBuffer {
        if buffer.format.sampleRate == outputFormat.sampleRate
            && buffer.format.channelCount == outputFormat.channelCount {
            return buffer
        }

        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: outputFormat)
        }
        guard let conv = converter else { return buffer }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else { return buffer }

        var error: NSError?
        var consumed = false
        conv.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let err = error {
            logger.error("Audio conversion failed: \(err.localizedDescription)")
            return buffer
        }

        return outputBuffer
    }

    // MARK: - CMSampleBuffer → AVAudioPCMBuffer

    static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard sampleBuffer.isValid,
              let formatDesc = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        else { return nil }

        let sampleRate = asbd.pointee.mSampleRate
        let channels = asbd.pointee.mChannelsPerFrame
        guard channels > 0, sampleRate > 0 else { return nil }

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        ) else { return nil }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy sample data into the PCM buffer
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                let ablPointer = audioBufferList.unsafePointer
                guard let srcData = ablPointer.pointee.mBuffers.mData else { return }
                let srcSize = Int(ablPointer.pointee.mBuffers.mDataByteSize)

                if let dstData = buffer.floatChannelData {
                    // Float32 format
                    let dstPointer = UnsafeMutableRawPointer(dstData[0])
                    let copySize = min(srcSize, Int(buffer.frameLength) * Int(channels) * MemoryLayout<Float>.size)
                    dstPointer.copyMemory(from: srcData, byteCount: copySize)
                } else if let dstData = buffer.int16ChannelData {
                    // Int16 format
                    let dstPointer = UnsafeMutableRawPointer(dstData[0])
                    let copySize = min(srcSize, Int(buffer.frameLength) * Int(channels) * MemoryLayout<Int16>.size)
                    dstPointer.copyMemory(from: srcData, byteCount: copySize)
                }
            }
        } catch {
            return nil
        }

        return buffer
    }
}
