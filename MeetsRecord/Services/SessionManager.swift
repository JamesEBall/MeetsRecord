import Foundation
import AppKit
import os

/// Manages the lifecycle of recording sessions: start, stop, pause,
/// file system organization, and post-recording transcription.
@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [RecordingSession] = []

    private let audioRecorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private let logger = Logger(subsystem: "MeetsRecord", category: "SessionManager")

    let recordingsDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        recordingsDirectory = docs.appendingPathComponent("MeetsRecord")

        try? FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )

        loadSessions()

        // Handle unexpected stream errors
        audioRecorder.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleStreamError(error)
            }
        }
    }

    // MARK: - Recording Controls

    func startRecording(state: RecordingState) async {
        // Check permissions
        do {
            if state.recordSystemAudio {
                try await PermissionManager.ensureScreenRecordingPermission()
            }
            if state.recordMicrophone {
                let micGranted = await PermissionManager.ensureMicrophonePermission()
                if !micGranted {
                    state.status = .error("Microphone permission denied")
                    return
                }
            }
        } catch {
            state.status = .error("Screen Recording permission required. Please enable in System Settings.")
            return
        }

        let session = RecordingSession(baseDirectory: recordingsDirectory)
        state.currentSession = session
        state.status = .recording
        state.startTimer()

        do {
            try await audioRecorder.startRecording(
                session: session,
                captureSystemAudio: state.recordSystemAudio,
                captureMicrophone: state.recordMicrophone
            )
            logger.info("Recording started: \(session.directoryURL.lastPathComponent)")
        } catch {
            state.status = .error("Failed to start: \(error.localizedDescription)")
            state.stopTimer()
            state.currentSession = nil
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func pauseRecording(state: RecordingState) {
        audioRecorder.pauseRecording()
        state.pauseTimer()
        state.status = .paused
    }

    func resumeRecording(state: RecordingState) {
        audioRecorder.resumeRecording()
        state.resumeTimer()
        state.status = .recording
    }

    func stopRecording(state: RecordingState) async {
        state.status = .stopping
        state.stopTimer()

        do {
            try await audioRecorder.stopRecording()
        } catch {
            logger.error("Error stopping recording: \(error.localizedDescription)")
            // Continue anyway — the audio file should still be valid
        }

        guard var session = state.currentSession else {
            state.status = .idle
            return
        }

        session.endDate = Date()
        session.durationSeconds = state.elapsedTime

        // Transcribe if model is available
        if transcriptionService.isModelAvailable {
            state.status = .transcribing
            state.transcriptionProgress = 0

            do {
                let transcript = try await transcriptionService.transcribe(
                    audioFileURL: session.audioFileURL,
                    progressHandler: { [weak state] progress in
                        Task { @MainActor in
                            state?.transcriptionProgress = progress
                        }
                    }
                )

                let transcriptURL = session.directoryURL.appendingPathComponent("transcript.txt")
                try transcript.write(to: transcriptURL, atomically: true, encoding: .utf8)
                session.transcriptFileURL = transcriptURL
                logger.info("Transcript saved: \(transcriptURL.lastPathComponent)")
            } catch {
                logger.error("Transcription failed: \(error.localizedDescription)")
                // Non-fatal — audio is already saved
            }
        } else {
            logger.warning("Whisper model not found, skipping transcription")
        }

        // Save session
        sessions.insert(session, at: 0)
        saveSessionManifest()

        state.reset()
        state.status = .idle

        logger.info("Session saved: \(session.displayName)")
    }

    // MARK: - File Management

    func openRecordingsFolder() {
        NSWorkspace.shared.open(recordingsDirectory)
    }

    func openSession(_ session: RecordingSession) {
        NSWorkspace.shared.open(session.directoryURL)
    }

    // MARK: - Private

    private func handleStreamError(_ error: Error) {
        logger.error("Stream error: \(error.localizedDescription)")
        // The audio file writer has already flushed and closed in the delegate
    }

    private var manifestURL: URL {
        recordingsDirectory.appendingPathComponent("sessions.json")
    }

    private func loadSessions() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([RecordingSession].self, from: data)
        else { return }
        sessions = decoded
        logger.info("Loaded \(self.sessions.count) previous sessions")
    }

    private func saveSessionManifest() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }
}
