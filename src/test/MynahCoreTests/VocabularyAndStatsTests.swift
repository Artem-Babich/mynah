// User story (Vocabulary): I add replacements like «super whisper → Superwhisper». After every
// dictation the pasted text has them applied — regardless of letter case, only on whole words,
// in any language.
//
// User story (Home): the settings Home page shows how much I dictate — total words, average
// speaking speed, in how many apps, and how much time I saved versus typing (40 WPM) — plus my
// recent dictations with the app I dictated into.

import Foundation
import Testing
@testable import MynahCore

@Suite("Vocabulary replacements")
struct VocabularyReplacerTests {
    private let rules = [
        Replacement(from: "super whisper", to: "Superwhisper"),
        Replacement(from: "кайро", to: "Kiro"),
    ]

    @Test("a phrase is replaced regardless of letter case")
    func caseInsensitive() {
        #expect(VocabularyReplacer.apply("I like Super Whisper a lot", rules) == "I like Superwhisper a lot")
    }

    @Test("Cyrillic phrases are replaced too")
    func cyrillic() {
        #expect(VocabularyReplacer.apply("Открой Кайро, пожалуйста", rules) == "Открой Kiro, пожалуйста")
    }

    @Test("only whole words are replaced, not parts of other words")
    func wholeWords() {
        #expect(VocabularyReplacer.apply("кайрос и кайро", rules) == "кайрос и Kiro")
    }

    @Test("every occurrence is replaced")
    func allOccurrences() {
        #expect(VocabularyReplacer.apply("кайро кайро", rules) == "Kiro Kiro")
    }

    @Test("rules with an empty 'from' are ignored and regex characters are treated literally")
    func edgeCases() {
        let tricky = [Replacement(from: "", to: "X"), Replacement(from: "c++", to: "C++")]
        #expect(VocabularyReplacer.apply("I write c++ code", tricky) == "I write C++ code")
    }
}

@Suite("History remembers the target app")
struct HistoryAppTests {
    @Test("history saved before this version (without app info) still loads")
    func backwardCompatible() throws {
        let old = #"[{"id":"7E1A4B4C-6F55-4D6A-9B3E-2B7C1C2E9F11","date":"2026-11-25T00:00:00Z","text":"hi","audioDuration":1.5}]"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([HistoryEntry].self, from: Data(old.utf8))
        #expect(entries.first?.text == "hi")
        #expect(entries.first?.appName == nil)
    }

    @Test("a new entry keeps the app it was dictated into")
    func storesApp() {
        let e = HistoryEntry(date: Date(), text: "x", audioDuration: 1, appBundleID: "com.google.Chrome", appName: "Google Chrome")
        #expect(e.appBundleID == "com.google.Chrome")
        #expect(e.appName == "Google Chrome")
    }
}

@Suite("Usage statistics on Home")
struct UsageStatsTests {
    private func entry(_ text: String, seconds: TimeInterval, app: String?) -> HistoryEntry {
        HistoryEntry(date: Date(), text: text, audioDuration: seconds, appBundleID: app, appName: app)
    }

    @Test("with no dictations everything is zero")
    func empty() {
        let s = UsageStats.compute([])
        #expect(s.words == 0 && s.averageWPM == 0 && s.appsUsed == 0 && s.timeSaved == 0)
    }

    @Test("words, average speed and distinct apps are counted across all dictations")
    func totals() {
        let s = UsageStats.compute([
            entry("one two three four five six", seconds: 3, app: "a"),      // 6 words
            entry("seven eight nine ten eleven twelve", seconds: 3, app: "b"), // 6 words
            entry("thirteen", seconds: 0, app: "a"),
        ])
        #expect(s.words == 13)
        #expect(s.averageWPM == 130)  // 13 words in 6 s
        #expect(s.appsUsed == 2)
    }

    @Test("time saved = typing time at 40 WPM minus time spent speaking, never negative")
    func timeSaved() {
        // 80 words: typing 120 s, speaking 30 s → 90 s saved
        let words = Array(repeating: "w", count: 80).joined(separator: " ")
        #expect(UsageStats.compute([entry(words, seconds: 30, app: nil)]).timeSaved == 90)
        // 1 word spoken slowly: typing 1.5 s, speaking 10 s → 0
        #expect(UsageStats.compute([entry("w", seconds: 10, app: nil)]).timeSaved == 0)
    }

    @Test("durations are shown compactly in Russian")
    func durationFormat() {
        #expect(DurationFormat.short(20) == "< 1 мин")
        #expect(DurationFormat.short(12 * 60) == "12 мин")
        #expect(DurationFormat.short(4 * 3600 + 5 * 60) == "4 ч 5 мин")
        #expect(DurationFormat.short(3 * 3600) == "3 ч")
    }
}

// User story (Shortcuts): besides ⌥W (tap = toggle, hold = push-to-talk) I can set a dedicated
// push-to-talk key: hold to record, release to stop. And a Send key: pressing it during a
// recording stops, pastes and presses Return (e.g. to send a chat message).
@Suite("Dedicated push-to-talk and Send keys")
struct HotkeyGestureExtraTests {
    @Test("holding the push-to-talk key starts recording; releasing it stops")
    func pttHoldRelease() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        #expect(g.pushToTalkDown() == .start)
        #expect(g.isRecording)
        #expect(g.pushToTalkUp() == .stop)
        #expect(!g.isRecording)
    }

    @Test("even a very short push-to-talk press stops on release (no toggle latch)")
    func pttShortPress() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.pushToTalkDown()
        #expect(g.pushToTalkUp() == .stop)
    }

    @Test("the push-to-talk key does nothing while a toggle recording is running")
    func pttIgnoredDuringToggle() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0); _ = g.keyUp(at: 0.1)
        #expect(g.pushToTalkDown() == .none)
        #expect(g.pushToTalkUp() == .none)
        #expect(g.isRecording)
    }

    @Test("Esc cancels a push-to-talk recording; the later release does nothing")
    func pttCancel() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.pushToTalkDown()
        #expect(g.cancel() == .cancel)
        #expect(g.pushToTalkUp() == .none)
        #expect(g.pushToTalkDown() == .start)
    }

    @Test("Send during a recording finishes it with the send action")
    func send() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0); _ = g.keyUp(at: 0.1)
        #expect(g.send() == .send)
        #expect(!g.isRecording)
        #expect(g.keyDown(at: 5) == .start)
    }

    @Test("Send while idle does nothing")
    func sendIdle() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        #expect(g.send() == .none)
    }

    @Test("Send while still holding ⌥W: the later ⌥W release does nothing")
    func sendWhileHolding() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0)
        #expect(g.send() == .send)
        #expect(g.keyUp(at: 2) == .none)
    }
}
