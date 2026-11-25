import Foundation

public struct HistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var text: String
    public var audioDuration: TimeInterval
    /// Frontmost app the text was pasted into (absent in history from older versions).
    public var appBundleID: String?
    public var appName: String?

    public init(
        id: UUID = UUID(), date: Date, text: String, audioDuration: TimeInterval,
        appBundleID: String? = nil, appName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.audioDuration = audioDuration
        self.appBundleID = appBundleID
        self.appName = appName
    }
}

/// Newest-first dictation history persisted as JSON. Not thread-safe: use from one actor.
public final class HistoryStore {
    public private(set) var entries: [HistoryEntry]
    private let fileURL: URL
    private let limit: Int

    public init(fileURL: URL, limit: Int = 500) {
        self.fileURL = fileURL
        self.limit = limit
        self.entries = Self.load(from: fileURL)
    }

    public func add(_ entry: HistoryEntry) throws {
        entries.insert(entry, at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        try save()
    }

    private func save() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(entries).write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }
}
