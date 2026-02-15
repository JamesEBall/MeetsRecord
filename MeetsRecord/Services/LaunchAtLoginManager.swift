import Foundation
import ServiceManagement
import os

/// Manages the "Open at Login" setting using SMAppService (macOS 13+).
@MainActor
class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            setLaunchAtLogin(isEnabled)
        }
    }

    private let logger = Logger(subsystem: "MeetsRecord", category: "LaunchAtLogin")
    private static let userDefaultsKey = "launchAtLoginEnabled"

    init() {
        // Check current system state
        let currentStatus = SMAppService.mainApp.status
        let systemEnabled = (currentStatus == .enabled)

        // Check if user has ever set a preference
        let hasUserPreference = UserDefaults.standard.object(forKey: Self.userDefaultsKey) != nil

        if !hasUserPreference {
            // First launch — enable by default
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.userDefaultsKey)
            if !systemEnabled {
                // Register with the system
                do {
                    try SMAppService.mainApp.register()
                    logger.info("Launch at login enabled (first launch default)")
                } catch {
                    logger.error("Failed to enable launch at login: \(error.localizedDescription)")
                    self.isEnabled = false
                    UserDefaults.standard.set(false, forKey: Self.userDefaultsKey)
                }
            }
        } else {
            // Respect the saved user preference
            let savedPref = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
            self.isEnabled = savedPref

            // Sync system state with user preference if needed
            if savedPref && !systemEnabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    logger.error("Failed to re-register launch at login: \(error.localizedDescription)")
                }
            } else if !savedPref && systemEnabled {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    logger.error("Failed to unregister launch at login: \(error.localizedDescription)")
                }
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.userDefaultsKey)

        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Launch at login disabled")
            }
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            // Revert the published value on failure
            Task { @MainActor in
                self.isEnabled = !enabled
                UserDefaults.standard.set(!enabled, forKey: Self.userDefaultsKey)
            }
        }
    }
}
