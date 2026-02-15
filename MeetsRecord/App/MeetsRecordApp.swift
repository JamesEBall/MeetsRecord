import SwiftUI

@main
struct MeetsRecordApp: App {
    @StateObject private var recordingState = RecordingState()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some Scene {
        MenuBarExtra {
            RecordingView()
                .environmentObject(recordingState)
                .environmentObject(sessionManager)
                .environmentObject(launchAtLogin)
        } label: {
            Label {
                Text("MeetsRecord")
            } icon: {
                Image(systemName: menuBarIcon)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        switch recordingState.status {
        case .recording:
            return "record.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .transcribing:
            return "text.badge.checkmark"
        default:
            return "waveform.circle"
        }
    }
}
