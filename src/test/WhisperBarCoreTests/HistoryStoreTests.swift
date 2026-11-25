// User story: every successful dictation is kept in a local history so I can
// re-copy something I said earlier from the menu-bar menu. History survives app restarts,
// is newest-first, is capped so it doesn't grow forever, and a damaged history file
// never prevents the app from starting.

import Foundation
import Testing
@testable import WhisperBarCore

@Suite("Dictation history")
struct HistoryStoreTests {
    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("whisperbar-tests-\(UUID().uuidString)")
            .appendingPathComponent("history.json")
    }

    private func entry(_ text: String, _ t: TimeInterval = 0) -> HistoryEntry {
        HistoryEntry(date: Date(timeIntervalSince1970: t), text: text, audioDuration: 1)
    }

    @Test("when no history file exists yet, history starts empty")
    func startsEmpty() {
        let store = HistoryStore(fileURL: tempFile())
        #expect(store.entries.isEmpty)
    }

    @Test("new entries appear first (newest-first order)")
    func newestFirst() throws {
        let store = HistoryStore(fileURL: tempFile())
        try store.add(entry("first", 1))
        try store.add(entry("second", 2))
        #expect(store.entries.map(\.text) == ["second", "first"])
    }

    @Test("history is persisted and reloaded after an app restart")
    func persists() throws {
        let url = tempFile()
        let store = HistoryStore(fileURL: url)
        try store.add(entry("remember me", 1))
        let reopened = HistoryStore(fileURL: url)
        #expect(reopened.entries.map(\.text) == ["remember me"])
    }

    @Test("when the limit is reached, the oldest entries are dropped")
    func capped() throws {
        let store = HistoryStore(fileURL: tempFile(), limit: 2)
        try store.add(entry("a", 1))
        try store.add(entry("b", 2))
        try store.add(entry("c", 3))
        #expect(store.entries.map(\.text) == ["c", "b"])
    }

    @Test("a corrupted history file is ignored and the app starts with empty history")
    func corruptFile() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = HistoryStore(fileURL: url)
        #expect(store.entries.isEmpty)
        try store.add(entry("fresh", 1))
        #expect(HistoryStore(fileURL: url).entries.map(\.text) == ["fresh"])
    }
}
