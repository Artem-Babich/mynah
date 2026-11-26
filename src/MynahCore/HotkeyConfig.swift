import Foundation

/// A Carbon hotkey: virtual key code + Carbon modifier mask.
public struct Hotkey: Equatable, Hashable, Codable, Sendable {
    public let keyCode: Int
    public let modifiers: Int

    public init(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Human-readable label, e.g. "⌥W".
    public var label: String { KeyNames.describe(keyCode: keyCode, modifiers: modifiers) }
}

public enum HotkeyConfig {
    /// ⌥W — kVK_ANSI_W (13) + optionKey (2048).
    public static let dictate = Hotkey(keyCode: 13, modifiers: 2048)
    /// Esc — kVK_Escape (53), registered only while recording.
    public static let cancel = Hotkey(keyCode: 53, modifiers: 0)
}
