import AppKit
import Combine
import MynahCore

enum AppPaths {
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Mynah", isDirectory: true)
    static let history = support.appendingPathComponent("history.json")
    static let settings = support.appendingPathComponent("settings.json")
}

/// Observable wrapper over SettingsStore: every change is saved immediately and broadcast.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            do { try store.update(settings) } catch { Log.info("settings save failed: \(error)") }
        }
    }
    /// True while the Shortcuts page is capturing a key combo: global hotkeys are paused.
    @Published var isCapturingShortcut = false

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore(fileURL: AppPaths.settings)) {
        self.store = store
        self.settings = store.settings
    }
}

/// Observable wrapper over HistoryStore for the menu and the Home page.
@MainActor
final class HistoryModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry]
    private let store: HistoryStore

    init(store: HistoryStore = HistoryStore(fileURL: AppPaths.history)) {
        self.store = store
        self.entries = store.entries
    }

    func add(_ entry: HistoryEntry) {
        do { try store.add(entry) } catch { Log.info("history save failed: \(error)") }
        entries = store.entries
    }
}

/// Plays the start/stop/cancel sounds of the selected theme at the selected volume.
enum SoundPlayer {
    static func play(_ event: SoundEvent, settings: AppSettings) {
        guard let name = settings.soundTheme.soundName(for: event),
              let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = Float(max(0, min(1, settings.soundVolume)))
        sound.play()
    }
}
