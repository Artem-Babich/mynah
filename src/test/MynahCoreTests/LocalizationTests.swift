// User story: WhisperBar's interface (menu, live bar, settings, messages) is in English by default.
// In Settings → General I can switch it to Russian; the switch is saved and applies everywhere.
// No text may be missing in either language.

import Foundation
import Testing
@testable import MynahCore

@Suite("Interface language")
struct LocalizationTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("mynah-l10n-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
    }

    @Test("the interface is in English by default")
    func defaultEnglish() {
        #expect(AppSettings().language == .en)
    }

    @Test("a settings file from before languages existed opens in English")
    func olderFileEnglish() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"soundTheme":"soft"}"#.utf8).write(to: url)
        #expect(SettingsStore(fileURL: url).settings.language == .en)
    }

    @Test("switching to Russian is saved and survives a restart")
    func persisted() throws {
        let url = tempFile()
        let store = SettingsStore(fileURL: url)
        var s = store.settings
        s.language = .ru
        try store.update(s)
        #expect(SettingsStore(fileURL: url).settings.language == .ru)
    }

    @Test("every interface text exists in both English and Russian")
    func complete() {
        for key in L.Key.allCases {
            #expect(!L.t(key, .en).isEmpty, "missing EN: \(key)")
            #expect(!L.t(key, .ru).isEmpty, "missing RU: \(key)")
        }
    }

    @Test("both languages use the same placeholders, so formatted texts never break")
    func placeholdersMatch() {
        func specs(_ s: String) -> [String] {
            let regex = try! NSRegularExpression(pattern: "%(@|d|%)")
            return regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { (s as NSString).substring(with: $0.range) }
        }
        for key in L.Key.allCases {
            #expect(specs(L.t(key, .en)) == specs(L.t(key, .ru)), "placeholder mismatch: \(key)")
        }
    }

    @Test("texts are shown in the chosen language")
    func chosenLanguage() {
        #expect(L.t(.recording, .en) == "Recording…")
        #expect(L.t(.recording, .ru) == "Запись…")
        #expect(L.f(.hotkeyTaken, .en, "⌥W").hasPrefix("⌥W"))
    }

    @Test("shortcut names and validation messages follow the language")
    func validationLocalized() {
        let s = AppSettings()
        #expect(HotkeyRole.cancel.title(.en) == "Cancel recording")
        #expect(HotkeyRole.cancel.title(.ru) == "Отмена записи")
        #expect(HotkeyValidation.problem(for: HotkeyConfig.dictate, role: .pushToTalk, in: s, language: .ru)?
            .contains("Уже занято") == true)
        #expect(HotkeyValidation.problem(for: HotkeyConfig.dictate, role: .pushToTalk, in: s, language: .en)?
            .contains("Already used") == true)
    }

    @Test("durations follow the language")
    func durations() {
        #expect(DurationFormat.short(65 * 60, language: .en) == "1 h 5 min")
        #expect(DurationFormat.short(20, language: .en) == "< 1 min")
        #expect(DurationFormat.short(65 * 60, language: .ru) == "1 ч 5 мин")
    }
}
