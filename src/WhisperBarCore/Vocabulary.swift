import Foundation

/// Applies user replacements to the final transcript: case-insensitive, whole words only.
public enum VocabularyReplacer {
    public static func apply(_ text: String, _ rules: [Replacement]) -> String {
        var result = text
        // Longer phrases first so "super whisper app" wins over "super whisper".
        for rule in rules.sorted(by: { $0.from.count > $1.from.count }) {
            let from = rule.from.trimmingCharacters(in: .whitespaces)
            guard !from.isEmpty else { continue }
            // Lookarounds instead of \b so phrases that start/end with symbols ("c++") work.
            let pattern = "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: from) + "(?![\\p{L}\\p{N}_])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: NSRegularExpression.escapedTemplate(for: rule.to))
        }
        return result
    }
}

/// Numbers on the settings Home page.
public struct UsageStats: Equatable, Sendable {
    public static let typingWPM: Double = 40

    public var words = 0
    public var averageWPM = 0
    public var appsUsed = 0
    /// Seconds saved vs typing at `typingWPM`.
    public var timeSaved: TimeInterval = 0

    public static func compute(_ entries: [HistoryEntry]) -> UsageStats {
        var stats = UsageStats()
        var spoken: TimeInterval = 0
        var apps = Set<String>()
        for entry in entries {
            let words = entry.text.split(whereSeparator: { $0.isWhitespace }).count
            stats.words += words
            spoken += entry.audioDuration
            stats.timeSaved += max(0, Double(words) / typingWPM * 60 - entry.audioDuration)
            if let app = entry.appBundleID { apps.insert(app) }
        }
        stats.appsUsed = apps.count
        stats.averageWPM = spoken > 0 ? Int((Double(stats.words) / spoken * 60).rounded()) : 0
        return stats
    }
}

public enum DurationFormat {
    public static func short(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 1 { return "< 1 мин" }
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) мин"
        case (_, 0): return "\(h) ч"
        default: return "\(h) ч \(m) мин"
        }
    }
}
