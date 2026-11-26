import Foundation
import ServiceManagement

/// "Launch on login" via SMAppService — the system login-items list is the source of truth.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message to show, or nil on success.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            Log.info("launch at login \(enabled) failed: \(error)")
            return error.localizedDescription
        }
    }
}
