import CoreGraphics
import Foundation

/// Text shown in the live bar while dictating.
public enum LiveTranscript {
    public static func compose(confirmed: String, volatile: String) -> String {
        [confirmed, volatile]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Latest words only, cut on a word boundary, prefixed with "…".
    public static func tail(_ text: String, maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        var suffix = Substring(text.suffix(maxChars))
        if let space = suffix.firstIndex(of: " ") {
            suffix = suffix[suffix.index(after: space)...]
        }
        return "…" + suffix
    }
}

/// Mic level 0…1 on a dB scale (−60 dB → 0, 0 dB → 1).
public enum AudioLevel {
    public static let floorDB: Float = -60

    public static func normalized(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        let rms = meanSquare.squareRoot()
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db - floorDB) / -floorDB))
    }
}

public enum ElapsedFormat {
    public static func string(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Bar frame: top-centre of the given screen's visible area (AppKit y-up coordinates).
public enum OverlayLayout {
    public static let width: CGFloat = 720
    public static let minHeight: CGFloat = 64
    /// Top + bottom padding around the text block.
    public static let verticalPadding: CGFloat = 40

    /// Height that fits the text, clamped to [minHeight, maxHeight].
    public static func panelHeight(textHeight: CGFloat, maxHeight: CGFloat) -> CGFloat {
        min(maxHeight, max(minHeight, textHeight + verticalPadding))
    }

    /// The bar never covers more than half of the visible screen.
    public static func maxHeight(visibleFrame: CGRect) -> CGFloat {
        visibleFrame.height / 2
    }

    public static func frame(visibleFrame: CGRect, size: CGSize, topMargin: CGFloat) -> CGRect {
        CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - topMargin - size.height,
            width: size.width,
            height: size.height)
    }
}
