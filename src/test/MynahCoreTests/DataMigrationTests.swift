// User story: the app was renamed from WhisperBar to Mynah. When I update, my settings,
// vocabulary and dictation history come with me automatically — nothing to copy by hand.
// If Mynah already has its own data, it is never overwritten.

import Foundation
import Testing
@testable import MynahCore

@Suite("Data migration from the old app name")
struct DataMigrationTests {
    private func sandbox() -> (old: URL, new: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mynah-migration-\(UUID().uuidString)")
        return (root.appendingPathComponent("WhisperBar"), root.appendingPathComponent("Mynah"))
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test("when only the old WhisperBar folder exists, it becomes the Mynah folder with all files")
    func movesOldFolder() throws {
        let (old, new) = sandbox()
        try write("{\"language\":\"ru\"}", to: old.appendingPathComponent("settings.json"))
        try write("[]", to: old.appendingPathComponent("history.json"))

        #expect(DataMigration.migrate(from: old, to: new) == .moved)
        #expect(FileManager.default.fileExists(atPath: new.appendingPathComponent("settings.json").path))
        #expect(FileManager.default.fileExists(atPath: new.appendingPathComponent("history.json").path))
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    @Test("when Mynah already has data, nothing is moved or overwritten")
    func keepsExistingData() throws {
        let (old, new) = sandbox()
        try write("old", to: old.appendingPathComponent("settings.json"))
        try write("new", to: new.appendingPathComponent("settings.json"))

        #expect(DataMigration.migrate(from: old, to: new) == .skippedDestinationExists)
        #expect(try String(contentsOf: new.appendingPathComponent("settings.json"), encoding: .utf8) == "new")
        #expect(FileManager.default.fileExists(atPath: old.path))
    }

    @Test("a fresh install with no old folder does nothing")
    func freshInstall() {
        let (old, new) = sandbox()
        #expect(DataMigration.migrate(from: old, to: new) == .nothingToMigrate)
        #expect(!FileManager.default.fileExists(atPath: new.path))
    }
}
