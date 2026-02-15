import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var state: RecordingState
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 12) {
            header
            Divider()

            switch state.status {
            case .idle:
                idleControls
            case .recording:
                recordingControls
            case .paused:
                pausedControls
            case .stopping:
                ProgressView("Saving...")
                    .padding(.vertical, 8)
            case .transcribing:
                transcribingView
            case .error(let message):
                errorView(message)
            }

            Divider()
            bottomSection
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(state.isRecording ? .red : .accentColor)
            Text("MeetsRecord")
                .font(.headline)
            Spacer()
            if state.isRecording {
                recordingIndicator
            }
        }
    }

    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(state.status == .recording ? 1 : 0.4)
            Text(formatTime(state.elapsedTime))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Idle State

    private var idleControls: some View {
        VStack(spacing: 10) {
            Toggle("System Audio", isOn: $state.recordSystemAudio)
            Toggle("Microphone", isOn: $state.recordMicrophone)

            Button(action: startRecording) {
                Label("Start Recording", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(!state.recordSystemAudio && !state.recordMicrophone)
        }
    }

    // MARK: - Recording State

    private var recordingControls: some View {
        HStack(spacing: 12) {
            Button(action: pauseRecording) {
                Label("Pause", systemImage: "pause.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: stopRecording) {
                Label("Stop", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
    }

    // MARK: - Paused State

    private var pausedControls: some View {
        VStack(spacing: 8) {
            Text("Paused")
                .font(.subheadline)
                .foregroundColor(.orange)

            HStack(spacing: 12) {
                Button(action: resumeRecording) {
                    Label("Resume", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: stopRecording) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Transcribing

    private var transcribingView: some View {
        VStack(spacing: 8) {
            ProgressView(value: state.transcriptionProgress) {
                Text("Transcribing...")
                    .font(.subheadline)
            }
            Text("\(Int(state.transcriptionProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
                .font(.caption)

            HStack {
                Button("Open Settings") {
                    PermissionManager.openScreenRecordingSettings()
                }
                Button("Dismiss") {
                    state.status = .idle
                }
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 6) {
            if !sessionManager.sessions.isEmpty {
                Menu("Recent Sessions (\(sessionManager.sessions.count))") {
                    ForEach(sessionManager.sessions.prefix(5)) { session in
                        Button(action: { sessionManager.openSession(session) }) {
                            Text("\(session.displayName) — \(session.formattedDuration)")
                        }
                    }
                    Divider()
                    Button("Open Recordings Folder") {
                        sessionManager.openRecordingsFolder()
                    }
                }
            }

            Button("Open Recordings Folder") {
                sessionManager.openRecordingsFolder()
            }

            Divider()

            Button("Quit MeetsRecord") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        Task {
            await sessionManager.startRecording(state: state)
        }
    }

    private func pauseRecording() {
        sessionManager.pauseRecording(state: state)
    }

    private func resumeRecording() {
        sessionManager.resumeRecording(state: state)
    }

    private func stopRecording() {
        Task {
            await sessionManager.stopRecording(state: state)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
