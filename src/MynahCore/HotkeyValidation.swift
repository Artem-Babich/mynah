import Foundation

public enum HotkeyRole: CaseIterable, Sendable {
    case toggle, pushToTalk, cancel, send

    /// Title in the current interface language.
    public var title: String { title(L.current) }

    /// Always registered (vs. only while recording).
    public var isAlwaysOn: Bool { self == .toggle || self == .pushToTalk }
}

extension AppSettings {
    public func hotkey(for role: HotkeyRole) -> Hotkey? {
        switch role {
        case .toggle: return toggleHotkey
        case .pushToTalk: return pushToTalkHotkey
        case .cancel: return cancelHotkey
        case .send: return sendHotkey
        }
    }

    public mutating func setHotkey(_ hotkey: Hotkey?, for role: HotkeyRole) {
        switch role {
        case .toggle: toggleHotkey = hotkey
        case .pushToTalk: pushToTalkHotkey = hotkey
        case .cancel: cancelHotkey = hotkey
        case .send: sendHotkey = hotkey
        }
    }
}

public enum HotkeyValidation {
    private static let fKeyCodes: Set<Int> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
    ]

    /// nil = OK, otherwise a message to show next to the shortcut.
    public static func problem(
        for hotkey: Hotkey, role: HotkeyRole, in settings: AppSettings, language: AppLanguage = L.current
    ) -> String? {
        if role.isAlwaysOn, hotkey.modifiers == 0, !fKeyCodes.contains(hotkey.keyCode) {
            return L.t(.validationNeedsModifier, language)
        }
        if let other = HotkeyRole.allCases.first(where: { $0 != role && settings.hotkey(for: $0) == hotkey }) {
            return L.f(.validationAlreadyUsed, language, other.title(language))
        }
        return nil
    }
}
