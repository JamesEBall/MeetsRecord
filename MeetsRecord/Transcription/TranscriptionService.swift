import Foundation
@preconcurrency import SwiftWhisper
import os

/// Transcribes audio files locally using SwiftWhisper (whisper.cpp).
@MainActor
class TranscriptionService {
    private let logger = Logger(subsystem: "MeetsRecord", category: "TranscriptionService")

    /// Returns the URL to the bundled Whisper model, or nil if not found.
    private var modelURL: URL? {
        Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")
    }

    /// Whether the Whisper model is available in the app bundle.
    var isModelAvailable: Bool {
        modelURL != nil
    }

    /// Transcribes audio from the given file URL.
    /// Returns timestamped transcript text.
    func transcribe(
        audioFileURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> String {
        guard let modelURL else {
            logger.error("Whisper model not found in bundle")
            throw TranscriptionError.modelNotFound
        }

        logger.info("Starting transcription of \(audioFileURL.lastPathComponent)")

        // Convert to 16kHz mono
        let audioFrames = try AudioConverter.convertTo16kHzMono(fileURL: audioFileURL)
        logger.info("Audio converted: \(audioFrames.count) samples")

        // Configure whisper
        var params = WhisperParams.default
        params.language = .english

        // Initialize whisper with model
        let whisper = Whisper(fromFileURL: modelURL, withParams: params)

        // Set up progress delegate
        let delegate = TranscriptionDelegate(progressHandler: progressHandler)
        whisper.delegate = delegate

        // Transcribe
        let segments = try await whisper.transcribe(audioFrames: audioFrames)

        logger.info("Transcription complete: \(segments.count) segments")

        // Format transcript with timestamps
        let transcript = segments.map { segment in
            let startTime = formatTimestamp(segment.startTime)
            let endTime = formatTimestamp(segment.endTime)
            let text = segment.text.trimmingCharacters(in: .whitespaces)
            return "[\(startTime) --> \(endTime)] \(text)"
        }.joined(separator: "\n")

        return transcript
    }

    private func formatTimestamp(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Whisper model (ggml-base.en.bin) not found. Add it to the app bundle."
        }
    }
}

// MARK: - Delegate

private class TranscriptionDelegate: WhisperDelegate {
    let progressHandler: @Sendable (Double) -> Void

    init(progressHandler: @escaping @Sendable (Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func whisper(_ aWhisper: Whisper, didUpdateProgress progress: Double) {
        progressHandler(progress)
    }

    func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {}
    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {}
    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {}
}
