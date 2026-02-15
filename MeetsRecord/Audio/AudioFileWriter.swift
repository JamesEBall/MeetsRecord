import AVFAudio
import os

/// Crash-safe incremental audio writer using CAF format.
/// Each write() call appends PCM data to disk immediately.
/// If the app crashes, all previously written data is recoverable.
class AudioFileWriter {
    private var audioFile: AVAudioFile?
    private let outputURL: URL
    private let logger = Logger(subsystem: "MeetsRecord", category: "AudioFileWriter")

    init(outputURL: URL, format: AVAudioFormat) throws {
        self.outputURL = outputURL

        let dir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false
        ]

        audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: true
        )

        logger.info("Opened CAF file for writing: \(outputURL.lastPathComponent)")
    }

    func write(buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0, let file = audioFile else { return }
        do {
            try file.write(from: buffer)
        } catch {
            logger.error("Failed to write audio buffer: \(error.localizedDescription)")
        }
    }

    func close() {
        audioFile = nil
        logger.info("Closed audio file: \(self.outputURL.lastPathComponent)")
    }
}
