import Foundation

public enum SoundEvent: Sendable { case start, stop, cancel }

public enum SoundTheme: String, Codable, CaseIterable, Sendable {
    case system, soft, off

    /// Name of a built-in macOS sound (`NSSound(named:)`), or nil for silence.
    public func soundName(for event: SoundEvent) -> String? {
        switch (self, event) {
        case (.system, .start): return "Tink"
        case (.system, .stop): return "Pop"
        case (.system, .cancel): return "Funk"
        case (.soft, .start): return "Morse"
        case (.soft, .stop): return "Purr"
        case (.soft, .cancel): return "Bottle"
        case (.off, _): return nil
        }
    }
}

/// What happens to playing media while recording.
public enum MediaBehavior: String, Codable, CaseIterable, Sendable { case pause, nothing }

/// Whether the live bar is shown while recording.
public enum RecordingWindowStyle: String, Codable, CaseIterable, Sendable { case bar, none }

public struct Replacement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var from: String
    public var to: String

    public init(id: UUID = UUID(), from: String, to: String) {
        self.id = id
        self.from = from
        self.to = to
    }
}

/// All user settings. Defaults reproduce the behaviour from before settings existed.
public struct AppSettings: Equatable, Sendable {
    /// Tap = toggle, hold = push-to-talk. nil = disabled.
    public var toggleHotkey: Hotkey? = HotkeyConfig.dictate
    /// Dedicated push-to-talk: hold to record, release to stop.
    public var pushToTalkHotkey: Hotkey? = nil
    /// Captured only while recording.
    public var cancelHotkey: Hotkey? = HotkeyConfig.cancel
    /// During recording: stop, paste, press Return. Captured only while recording.
    public var sendHotkey: Hotkey? = nil
    public var soundTheme: SoundTheme = .system
    /// 0…1
    public var soundVolume: Double = 1.0
    /// CoreAudio device UID; nil = system default input.
    public var inputDeviceUID: String? = nil
    public var mediaWhileRecording: MediaBehavior = .pause
    public var recordingWindow: RecordingWindowStyle = .bar
    public var replacements: [Replacement] = []
    /// Interface language; English by default.
    public var language: AppLanguage = .en

    public init() {}
}

extension AppSettings: Codable {
    private enum Keys: String, CodingKey {
        case toggleHotkey, pushToTalkHotkey, cancelHotkey, sendHotkey, soundTheme, soundVolume,
            inputDeviceUID, mediaWhileRecording, recordingWindow, replacements, language
    }

    // Every key is optional: files from older versions keep their values, new ones get defaults.
    // Hotkeys are stored as `null` when cleared, so "absent" (→ default) ≠ "null" (→ disabled).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let d = AppSettings()
        func hotkey(_ key: Keys, _ fallback: Hotkey?) throws -> Hotkey? {
            c.contains(key) ? try c.decodeIfPresent(Hotkey.self, forKey: key) : fallback
        }
        toggleHotkey = try hotkey(.toggleHotkey, d.toggleHotkey)
        pushToTalkHotkey = try hotkey(.pushToTalkHotkey, d.pushToTalkHotkey)
        cancelHotkey = try hotkey(.cancelHotkey, d.cancelHotkey)
        sendHotkey = try hotkey(.sendHotkey, d.sendHotkey)
        soundTheme = (try? c.decodeIfPresent(SoundTheme.self, forKey: .soundTheme)) ?? d.soundTheme
        soundVolume = (try? c.decodeIfPresent(Double.self, forKey: .soundVolume)) ?? d.soundVolume
        inputDeviceUID = try? c.decodeIfPresent(String.self, forKey: .inputDeviceUID)
        mediaWhileRecording = (try? c.decodeIfPresent(MediaBehavior.self, forKey: .mediaWhileRecording))
            ?? d.mediaWhileRecording
        recordingWindow = (try? c.decodeIfPresent(RecordingWindowStyle.self, forKey: .recordingWindow))
            ?? d.recordingWindow
        replacements = (try? c.decodeIfPresent([Replacement].self, forKey: .replacements)) ?? d.replacements
        language = (try? c.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? d.language
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(toggleHotkey, forKey: .toggleHotkey)
        try c.encode(pushToTalkHotkey, forKey: .pushToTalkHotkey)
        try c.encode(cancelHotkey, forKey: .cancelHotkey)
        try c.encode(sendHotkey, forKey: .sendHotkey)
        try c.encode(soundTheme, forKey: .soundTheme)
        try c.encode(soundVolume, forKey: .soundVolume)
        try c.encode(inputDeviceUID, forKey: .inputDeviceUID)
        try c.encode(mediaWhileRecording, forKey: .mediaWhileRecording)
        try c.encode(recordingWindow, forKey: .recordingWindow)
        try c.encode(replacements, forKey: .replacements)
        try c.encode(language, forKey: .language)
    }
}

/// Settings persisted as JSON. Not thread-safe: use from one actor (main).
public final class SettingsStore {
    public private(set) var settings: AppSettings
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = loaded
        } else {
            settings = AppSettings()
        }
    }

    public func update(_ settings: AppSettings) throws {
        self.settings = settings
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: fileURL, options: .atomic)
    }
}
