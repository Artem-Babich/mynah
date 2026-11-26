import Foundation

public enum TranscriptCleaner {
    /// Tidy model output for pasting; `nil` means "nothing to paste".
    public static func clean(_ raw: String) -> String? {
        let words = raw
            .replacingOccurrences(of: "<unk>", with: "")
            .split(whereSeparator: { $0.isWhitespace })
        return words.isEmpty ? nil : words.joined(separator: " ")
    }
}
