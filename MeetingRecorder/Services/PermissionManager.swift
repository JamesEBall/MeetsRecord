import ScreenCaptureKit
import AVFoundation
import AppKit

/// Handles checking and requesting Screen Recording and Microphone permissions.
struct PermissionManager {

    /// Triggers the screen recording permission prompt if not yet granted.
    /// If previously denied, throws an error — user must enable in System Settings.
    static func ensureScreenRecordingPermission() async throws {
        _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
    }

    /// Checks/requests microphone permission. Returns true if granted.
    static func ensureMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
