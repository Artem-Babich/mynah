// User story: WhisperBar has a settings window. Whatever I change there is saved and survives
// restarts. Fresh installs behave exactly like before settings existed (⌥W toggle, Esc cancel,
// system sounds, pause music, live bar). A damaged or older settings file never breaks startup:
// missing values fall back to defaults.

import Foundation
import Testing
@testable import MynahCore

@Suite("Settings: defaults and persistence")
struct SettingsTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("mynah-settings-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
    }

    @Test("defaults keep today's behaviour: ⌥W toggle, Esc cancel, no PTT/Send keys, system sounds, pause media, live bar")
    func defaults() {
        let s = AppSettings()
        #expect(s.toggleHotkey == HotkeyConfig.dictate)
        #expect(s.cancelHotkey == HotkeyConfig.cancel)
        #expect(s.pushToTalkHotkey == nil)
        #expect(s.sendHotkey == nil)
        #expect(s.soundTheme == .system)
        #expect(s.soundVolume == 1.0)
        #expect(s.inputDeviceUID == nil)
        #expect(s.mediaWhileRecording == .pause)
        #expect(s.recordingWindow == .bar)
        #expect(s.replacements.isEmpty)
    }

    @Test("when no settings file exists, defaults are used")
    func missingFile() {
        #expect(SettingsStore(fileURL: tempFile()).settings == AppSettings())
    }

    @Test("changed settings are saved and reloaded after restart")
    func persists() throws {
        let url = tempFile()
        let store = SettingsStore(fileURL: url)
        var s = store.settings
        s.soundTheme = .off
        s.pushToTalkHotkey = Hotkey(keyCode: 96, modifiers: 0)
        s.replacements = [Replacement(from: "super whisper", to: "Superwhisper")]
        try store.update(s)
        let reopened = SettingsStore(fileURL: url).settings
        #expect(reopened.soundTheme == .off)
        #expect(reopened.pushToTalkHotkey == Hotkey(keyCode: 96, modifiers: 0))
        #expect(reopened.replacements.map(\.to) == ["Superwhisper"])
    }

    @Test("a corrupted settings file is ignored and defaults are used")
    func corrupted() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{{nope".utf8).write(to: url)
        #expect(SettingsStore(fileURL: url).settings == AppSettings())
    }

    @Test("a settings file from an older version keeps its values and fills new ones with defaults")
    func partialFile() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"soundTheme":"off"}"#.utf8).write(to: url)
        let s = SettingsStore(fileURL: url).settings
        #expect(s.soundTheme == .off)
        #expect(s.toggleHotkey == HotkeyConfig.dictate)
        #expect(s.mediaWhileRecording == .pause)
    }

    @Test("a hotkey can be cleared (nil) and stays cleared after restart")
    func clearedHotkey() throws {
        let url = tempFile()
        let store = SettingsStore(fileURL: url)
        var s = store.settings
        s.toggleHotkey = nil
        try store.update(s)
        #expect(SettingsStore(fileURL: url).settings.toggleHotkey == nil)
    }
}

// User story: in Shortcuts I see each hotkey written the way macOS writes it (⌃⌥⇧⌘ + key).
@Suite("Hotkey labels")
struct KeyNamesTests {
    @Test("modifiers are written in macOS order ⌃⌥⇧⌘ before the key")
    func order() {
        #expect(Hotkey(keyCode: 40, modifiers: 2048 | 512).label == "⌥⇧K")
        #expect(Hotkey(keyCode: 49, modifiers: 4096 | 256).label == "⌃⌘Space")
        #expect(Hotkey(keyCode: 13, modifiers: 2048).label == "⌥W")
    }

    @Test("special keys have readable names")
    func specialKeys() {
        #expect(Hotkey(keyCode: 53, modifiers: 0).label == "Esc")
        #expect(Hotkey(keyCode: 36, modifiers: 0).label == "Return")
        #expect(Hotkey(keyCode: 96, modifiers: 0).label == "F5")
        #expect(Hotkey(keyCode: 18, modifiers: 256).label == "⌘1")
    }

    @Test("an unknown key code still gets a label")
    func unknown() {
        #expect(Hotkey(keyCode: 999, modifiers: 0).label == "Key 999")
    }
}

// User story: in Sound I pick a sound set or turn sounds off.
@Suite("Sound themes")
struct SoundThemeTests {
    @Test("the system set uses the same sounds as before settings existed")
    func system() {
        #expect(SoundTheme.system.soundName(for: .start) == "Tink")
        #expect(SoundTheme.system.soundName(for: .stop) == "Pop")
        #expect(SoundTheme.system.soundName(for: .cancel) == "Funk")
    }

    @Test("the soft set uses different, quieter system sounds")
    func soft() {
        for event in [SoundEvent.start, .stop, .cancel] {
            #expect(SoundTheme.soft.soundName(for: event) != nil)
            #expect(SoundTheme.soft.soundName(for: event) != SoundTheme.system.soundName(for: event))
        }
    }

    @Test("off plays nothing")
    func off() {
        #expect(SoundTheme.off.soundName(for: .start) == nil)
        #expect(SoundTheme.off.soundName(for: .stop) == nil)
        #expect(SoundTheme.off.soundName(for: .cancel) == nil)
    }
}
