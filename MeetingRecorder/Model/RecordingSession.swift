import Foundation

struct RecordingSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    let directoryURL: URL
    let audioFileURL: URL
    var transcriptFileURL: URL?
    var durationSeconds: TimeInterval?

    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: startDate)
    }

    var formattedDuration: String {
        guard let dur = durationSeconds else { return "--:--" }
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        let s = Int(dur) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    init(baseDirectory: URL) {
        self.id = UUID()
        self.startDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let folderName = formatter.string(from: startDate)
        self.directoryURL = baseDirectory.appendingPathComponent(folderName)
        self.audioFileURL = directoryURL.appendingPathComponent("recording.caf")
    }
}
