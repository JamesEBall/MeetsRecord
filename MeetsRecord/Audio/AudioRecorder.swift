import ScreenCaptureKit
import AVFAudio
import CoreMedia
import os

enum RecorderError: LocalizedError {
    case noDisplayFound
    case audioConversionFailed
    case streamNotRunning
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found for audio capture"
        case .audioConversionFailed: return "Audio format conversion failed"
        case .streamNotRunning: return "Recording stream is not running"
        case .permissionDenied: return "Screen recording permission denied"
        }
    }
}

/// Core recording engine using ScreenCaptureKit.
/// Captures system audio output and microphone input via a single SCStream.
@MainActor
class AudioRecorder: NSObject, ObservableObject {
    private var stream: SCStream?
    private var audioFileWriter: AudioFileWriter?
    private var audioMixer: AudioMixer?

    private let systemAudioQueue = DispatchQueue(label: "com.meetsrecord.systemaudio", qos: .userInitiated)
    private let micAudioQueue = DispatchQueue(label: "com.meetsrecord.micaudio", qos: .userInitiated)
    private let logger = Logger(subsystem: "MeetsRecord", category: "AudioRecorder")

    var onError: ((Error) -> Void)?

    func startRecording(
        session: RecordingSession,
        captureSystemAudio: Bool,
        captureMicrophone: Bool
    ) async throws {
        // Get shareable content (triggers permission prompt if needed)
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            logger.error("Failed to get shareable content: \(error.localizedDescription)")
            throw RecorderError.permissionDenied
        }

        guard let mainDisplay = content.displays.first else {
            throw RecorderError.noDisplayFound
        }

        // Filter: entire display (we want all system audio)
        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])

        // Configure stream — minimize video overhead, we only want audio
        let config = SCStreamConfiguration()
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        // System audio
        config.capturesAudio = captureSystemAudio
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true

        // Microphone (macOS 15+)
        if captureMicrophone {
            config.captureMicrophone = true
        }

        // Set up audio pipeline
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 2
        )!

        let writer = try AudioFileWriter(outputURL: session.audioFileURL, format: outputFormat)
        let mixer = AudioMixer(outputFormat: outputFormat, writer: writer)

        self.audioFileWriter = writer
        self.audioMixer = mixer

        // Create and start stream
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)

        if captureSystemAudio {
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: systemAudioQueue)
        }
        if captureMicrophone {
            try newStream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: micAudioQueue)
        }

        try await newStream.startCapture()
        self.stream = newStream

        logger.info("Recording started — system audio: \(captureSystemAudio), mic: \(captureMicrophone)")
    }

    func stopRecording() async throws {
        guard let stream = stream else {
            throw RecorderError.streamNotRunning
        }

        try await stream.stopCapture()
        self.stream = nil

        audioMixer?.flush()
        audioFileWriter?.close()
        audioFileWriter = nil
        audioMixer = nil

        logger.info("Recording stopped")
    }

    func pauseRecording() {
        audioMixer?.isPaused = true
        logger.info("Recording paused")
    }

    func resumeRecording() {
        audioMixer?.isPaused = false
        logger.info("Recording resumed")
    }
}

// MARK: - SCStreamOutput

extension AudioRecorder: SCStreamOutput {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard sampleBuffer.isValid else { return }

        // Access mixer directly — it's thread-safe via its internal lock.
        // We capture it once to avoid repeated main-actor hops.
        let mixer = MainActor.assumeIsolated { self.audioMixer }

        switch outputType {
        case .screen:
            break
        case .audio:
            mixer?.appendSystemAudioBuffer(sampleBuffer)
        case .microphone:
            mixer?.appendMicrophoneBuffer(sampleBuffer)
        @unknown default:
            break
        }
    }
}

// MARK: - SCStreamDelegate

extension AudioRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.error("Stream stopped with error: \(error.localizedDescription)")
            self.audioMixer?.flush()
            self.audioFileWriter?.close()
            self.onError?(error)
        }
    }
}
