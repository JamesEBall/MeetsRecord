import Foundation
import Combine

enum RecorderStatus: Equatable {
    case idle
    case recording
    case paused
    case stopping
    case transcribing
    case error(String)
}

@MainActor
class RecordingState: ObservableObject {
    @Published var status: RecorderStatus = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentSession: RecordingSession?
    @Published var transcriptionProgress: Double = 0
    @Published var recordSystemAudio: Bool = true
    @Published var recordMicrophone: Bool = true

    var isRecording: Bool {
        status == .recording || status == .paused
    }

    var statusText: String {
        switch status {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .stopping: return "Saving..."
        case .transcribing: return "Transcribing..."
        case .error(let msg): return msg
        }
    }

    private var timerStart: Date?
    private var accumulatedBeforePause: TimeInterval = 0
    private var timerCancellable: AnyCancellable?

    func startTimer() {
        accumulatedBeforePause = 0
        timerStart = Date()
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.timerStart else { return }
                self.elapsedTime = self.accumulatedBeforePause + Date().timeIntervalSince(start)
            }
    }

    func pauseTimer() {
        if let start = timerStart {
            accumulatedBeforePause += Date().timeIntervalSince(start)
        }
        timerStart = nil
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func resumeTimer() {
        timerStart = Date()
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.timerStart else { return }
                self.elapsedTime = self.accumulatedBeforePause + Date().timeIntervalSince(start)
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timerStart = nil
        accumulatedBeforePause = 0
    }

    func reset() {
        stopTimer()
        elapsedTime = 0
        currentSession = nil
        transcriptionProgress = 0
    }
}
