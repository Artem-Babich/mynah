import AppKit
import MynahCore

// Bring settings + history over from the pre-rename "WhisperBar" folder before any store opens it.
let migration = DataMigration.migrate(
    from: AppPaths.support.deletingLastPathComponent().appendingPathComponent("WhisperBar", isDirectory: true),
    to: AppPaths.support)
if migration != .nothingToMigrate { Log.info("data migration from WhisperBar: \(migration)") }

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
    app.run()
}
