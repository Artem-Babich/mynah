import Foundation

/// Hotkey labels in macOS style: ⌃⌥⇧⌘ + key name. Key codes are Carbon virtual key codes
/// (ANSI layout positions), modifiers are Carbon masks.
public enum KeyNames {
    public static let cmd = 256, shift = 512, option = 2048, control = 4096

    public static func describe(keyCode: Int, modifiers: Int) -> String {
        var label = ""
        if modifiers & control != 0 { label += "⌃" }
        if modifiers & option != 0 { label += "⌥" }
        if modifiers & shift != 0 { label += "⇧" }
        if modifiers & cmd != 0 { label += "⌘" }
        return label + (names[keyCode] ?? "Key \(keyCode)")
    }

    private static let names: [Int: String] = {
        var n: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
            27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 50: "`",
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End",
            116: "PgUp", 121: "PgDn", 76: "Enter",
        ]
        let fKeys = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
        for (i, code) in fKeys.enumerated() { n[code] = "F\(i + 1)" }
        return n
    }()
}
