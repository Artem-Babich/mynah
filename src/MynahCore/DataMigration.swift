import Foundation

/// One-time move of the data folder after the WhisperBar → Mynah rename.
public enum DataMigration {
    public enum Result: Equatable, Sendable { case moved, skippedDestinationExists, nothingToMigrate, failed(String) }

    /// Moves `old` to `new` only when `old` exists and `new` does not; never overwrites.
    public static func migrate(from old: URL, to new: URL, fileManager: FileManager = .default) -> Result {
        guard fileManager.fileExists(atPath: old.path) else { return .nothingToMigrate }
        guard !fileManager.fileExists(atPath: new.path) else { return .skippedDestinationExists }
        do {
            try fileManager.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: old, to: new)
            return .moved
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
