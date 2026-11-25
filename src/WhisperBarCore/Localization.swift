import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case en, ru

    /// Shown in the language picker in its own language.
    public var nativeName: String { self == .en ? "English" : "Русский" }
    public var locale: Locale { Locale(identifier: self == .en ? "en_US" : "ru_RU") }
}

/// Interface strings. Our own table (not .lproj) so the language switches live, without restart.
public enum L {
    /// Set by the app from settings; used when no language is passed explicitly.
    nonisolated(unsafe) public static var current: AppLanguage = .en

    public static func t(_ key: Key, _ language: AppLanguage = current) -> String {
        table(language)[key] ?? en[key] ?? key.rawValue
    }

    /// Formatted text: `%@` for strings, `%d` for integers.
    public static func f(_ key: Key, _ language: AppLanguage = current, _ args: CVarArg...) -> String {
        String(format: t(key, language), locale: language.locale, arguments: args)
    }

    private static func table(_ language: AppLanguage) -> [Key: String] {
        language == .en ? en : ru
    }

    public enum Key: String, CaseIterable, Sendable {
        // status & menu
        case loadingModel, loadingModelPercent, ready, readyNoHotkey, tapOrHold, holdOnly, recording, transcribing
        case hotkeyTaken, historyEmpty, recentHeader
        case menuSettings, menuOpenHistory, menuOpenLog, menuGrantAccessibility, menuResetError, menuQuit
        case errModel, errMicrophone, errNoAccessibility, errTranscription, errModelNotLoaded
        case errNoMicrophone, errAudioConversion
        // hidden main menu
        case menuCloseWindow, menuEdit, menuUndo, menuRedo, menuCut, menuCopy, menuPaste, menuSelectAll
        // live bar
        case barSpeak
        // settings window
        case settingsTitle, pageHome, pageVocabulary, pageShortcuts, pageSound, pageGeneral
        case statWPM, statWords, statApps, statSaved, recentRecordings, emptyHistory, copied, clickToCopy
        case vocabFrom, vocabTo, vocabAdd, vocabFooter, vocabHeader, vocabEmpty, vocabDeleteMarker
        case shortcutsHeader, roleToggle, roleToggleHint, rolePushToTalk, rolePushToTalkHint
        case roleCancel, roleCancelHint, roleSend, roleSendHint
        case shortcutPress, shortcutNotSet, shortcutChange, shortcutCancel, shortcutReset
        case validationNeedsModifier, validationAlreadyUsed
        case soundEffects, soundSet, themeSystem, themeSoft, themeOff
        case recordingSection, microphone, microphoneDefault, microphoneMissing
        case mediaWhileRecording, mediaPause, mediaNothing
        case recordingWindowSection, recordingWindowLabel, windowBar, windowNone
        case applicationSection, launchAtLogin, openLog, openDataFolder, language
        // durations
        case durationUnderMinute, durationMinutes, durationHours, durationHoursMinutes
    }

    private static let en: [Key: String] = [
        .loadingModel: "Loading model…",
        .loadingModelPercent: "Loading model… %d%%",
        .ready: "Ready — %@",
        .readyNoHotkey: "Ready — no shortcut set (Settings → Shortcuts)",
        .tapOrHold: "%@ (tap/hold)",
        .holdOnly: "%@ (hold)",
        .recording: "Recording…",
        .transcribing: "Transcribing…",
        .hotkeyTaken: "%@ is taken by another app (superwhisper?)",
        .historyEmpty: "History is empty",
        .recentHeader: "Recent (click to copy)",
        .menuSettings: "Settings…",
        .menuOpenHistory: "Open history (JSON)",
        .menuOpenLog: "Open log",
        .menuGrantAccessibility: "Allow pasting (Accessibility)…",
        .menuResetError: "Reset error",
        .menuQuit: "Quit",
        .errModel: "Model: %@",
        .errMicrophone: "Microphone: %@",
        .errNoAccessibility: "No Accessibility access — text is on the clipboard",
        .errTranscription: "Transcription: %@",
        .errModelNotLoaded: "The model isn't loaded yet",
        .errNoMicrophone: "No microphone available",
        .errAudioConversion: "Couldn't set up audio conversion",
        .menuCloseWindow: "Close Window",
        .menuEdit: "Edit",
        .menuUndo: "Undo",
        .menuRedo: "Redo",
        .menuCut: "Cut",
        .menuCopy: "Copy",
        .menuPaste: "Paste",
        .menuSelectAll: "Select All",
        .barSpeak: "Speak…  (Esc to cancel)",
        .settingsTitle: "WhisperBar — Settings",
        .pageHome: "Home",
        .pageVocabulary: "Vocabulary",
        .pageShortcuts: "Shortcuts",
        .pageSound: "Sound",
        .pageGeneral: "General",
        .statWPM: "words per minute",
        .statWords: "words total",
        .statApps: "apps",
        .statSaved: "saved vs typing at 40 WPM",
        .recentRecordings: "Recent recordings",
        .emptyHistory: "Nothing yet — press %@ and say something.",
        .copied: "Copied",
        .clickToCopy: "Click to copy",
        .vocabFrom: "Recognized as",
        .vocabTo: "Replace with",
        .vocabAdd: "Add",
        .vocabFooter: "Replacements are applied to the text before pasting: case-insensitive, whole words only.",
        .vocabHeader: "Replacements",
        .vocabEmpty: "No replacements yet",
        .vocabDeleteMarker: "(remove)",
        .shortcutsHeader: "Keyboard shortcuts",
        .roleToggle: "Record (tap / hold)",
        .roleToggleHint: "Tap to start/stop, hold to record while held",
        .rolePushToTalk: "Push to Talk",
        .rolePushToTalkHint: "Hold to record, release when done",
        .roleCancel: "Cancel recording",
        .roleCancelHint: "During a recording: discard without pasting",
        .roleSend: "Send",
        .roleSendHint: "During a recording: paste the text and press Return",
        .shortcutPress: "Press a shortcut…  ⌫ clears",
        .shortcutNotSet: "Not set",
        .shortcutChange: "Change",
        .shortcutCancel: "Cancel",
        .shortcutReset: "Restore default",
        .validationNeedsModifier: "Needs a modifier (⌃⌥⇧⌘) or an F-key — otherwise the key stops typing",
        .validationAlreadyUsed: "Already used: %@",
        .soundEffects: "Sound effects",
        .soundSet: "Set",
        .themeSystem: "System",
        .themeSoft: "Soft",
        .themeOff: "Off",
        .recordingSection: "Recording",
        .microphone: "Microphone",
        .microphoneDefault: "System default",
        .microphoneMissing: "Disconnected — using system default",
        .mediaWhileRecording: "Music while recording",
        .mediaPause: "Pause",
        .mediaNothing: "Do nothing",
        .recordingWindowSection: "Recording window",
        .recordingWindowLabel: "Show while recording",
        .windowBar: "Live bar",
        .windowNone: "No window",
        .applicationSection: "Application",
        .launchAtLogin: "Launch at login",
        .openLog: "Open log",
        .openDataFolder: "Open data folder",
        .language: "Language",
        .durationUnderMinute: "< 1 min",
        .durationMinutes: "%d min",
        .durationHours: "%d h",
        .durationHoursMinutes: "%d h %d min",
    ]

    private static let ru: [Key: String] = [
        .loadingModel: "Загрузка модели…",
        .loadingModelPercent: "Загрузка модели… %d%%",
        .ready: "Готово — %@",
        .readyNoHotkey: "Готово — хоткей не задан (Настройки → Горячие клавиши)",
        .tapOrHold: "%@ (нажать/удерживать)",
        .holdOnly: "%@ (удерживать)",
        .recording: "Запись…",
        .transcribing: "Распознавание…",
        .hotkeyTaken: "%@ занят другим приложением (superwhisper?)",
        .historyEmpty: "История пуста",
        .recentHeader: "Последние (клик — скопировать)",
        .menuSettings: "Настройки…",
        .menuOpenHistory: "Открыть историю (JSON)",
        .menuOpenLog: "Открыть лог",
        .menuGrantAccessibility: "Разрешить вставку (Accessibility)…",
        .menuResetError: "Сбросить ошибку",
        .menuQuit: "Выход",
        .errModel: "Модель: %@",
        .errMicrophone: "Микрофон: %@",
        .errNoAccessibility: "Нет доступа Accessibility — текст в буфере",
        .errTranscription: "Распознавание: %@",
        .errModelNotLoaded: "Модель ещё не загружена",
        .errNoMicrophone: "Нет доступного микрофона",
        .errAudioConversion: "Не удалось настроить конвертацию аудио",
        .menuCloseWindow: "Закрыть окно",
        .menuEdit: "Правка",
        .menuUndo: "Отменить",
        .menuRedo: "Повторить",
        .menuCut: "Вырезать",
        .menuCopy: "Копировать",
        .menuPaste: "Вставить",
        .menuSelectAll: "Выбрать все",
        .barSpeak: "Говорите…  (Esc — отмена)",
        .settingsTitle: "WhisperBar — настройки",
        .pageHome: "Главная",
        .pageVocabulary: "Словарь",
        .pageShortcuts: "Горячие клавиши",
        .pageSound: "Звук",
        .pageGeneral: "Общие",
        .statWPM: "слов в минуту",
        .statWords: "слов всего",
        .statApps: "приложений",
        .statSaved: "сэкономлено vs печать 40 WPM",
        .recentRecordings: "Недавние записи",
        .emptyHistory: "Пока пусто — нажмите %@ и скажите что-нибудь.",
        .copied: "Скопировано",
        .clickToCopy: "Клик — скопировать",
        .vocabFrom: "Что распозналось",
        .vocabTo: "На что заменить",
        .vocabAdd: "Добавить",
        .vocabFooter: "Замены применяются к тексту перед вставкой: без учёта регистра, только целые слова.",
        .vocabHeader: "Замены",
        .vocabEmpty: "Пока нет замен",
        .vocabDeleteMarker: "(удалить)",
        .shortcutsHeader: "Горячие клавиши",
        .roleToggle: "Запись (нажать / удерживать)",
        .roleToggleHint: "Нажать — старт/стоп, удерживать — запись, пока держишь",
        .rolePushToTalk: "Push to Talk",
        .rolePushToTalkHint: "Удерживать — запись, отпустить — готово",
        .roleCancel: "Отмена записи",
        .roleCancelHint: "Во время записи: отменить без вставки",
        .roleSend: "Отправить",
        .roleSendHint: "Во время записи: вставить текст и нажать Return",
        .shortcutPress: "Нажмите сочетание…  ⌫ — очистить",
        .shortcutNotSet: "Не задано",
        .shortcutChange: "Изменить",
        .shortcutCancel: "Отмена",
        .shortcutReset: "Вернуть по умолчанию",
        .validationNeedsModifier: "Нужен модификатор (⌃⌥⇧⌘) или F-клавиша — иначе клавиша перестанет печатать",
        .validationAlreadyUsed: "Уже занято: %@",
        .soundEffects: "Звуковые эффекты",
        .soundSet: "Набор",
        .themeSystem: "Системные",
        .themeSoft: "Мягкие",
        .themeOff: "Выкл",
        .recordingSection: "Запись",
        .microphone: "Микрофон",
        .microphoneDefault: "Системный (по умолчанию)",
        .microphoneMissing: "Отключён — используется системный",
        .mediaWhileRecording: "Музыка во время записи",
        .mediaPause: "Ставить на паузу",
        .mediaNothing: "Ничего не делать",
        .recordingWindowSection: "Окно записи",
        .recordingWindowLabel: "Во время записи показывать",
        .windowBar: "Живой бар",
        .windowNone: "Без окна",
        .applicationSection: "Приложение",
        .launchAtLogin: "Запускать при входе в систему",
        .openLog: "Открыть лог",
        .openDataFolder: "Открыть папку данных",
        .language: "Язык",
        .durationUnderMinute: "< 1 мин",
        .durationMinutes: "%d мин",
        .durationHours: "%d ч",
        .durationHoursMinutes: "%d ч %d мин",
    ]
}

extension HotkeyRole {
    public func title(_ language: AppLanguage) -> String {
        switch self {
        case .toggle: return L.t(.roleToggle, language)
        case .pushToTalk: return L.t(.rolePushToTalk, language)
        case .cancel: return L.t(.roleCancel, language)
        case .send: return L.t(.roleSend, language)
        }
    }

    public func hint(_ language: AppLanguage) -> String {
        switch self {
        case .toggle: return L.t(.roleToggleHint, language)
        case .pushToTalk: return L.t(.rolePushToTalkHint, language)
        case .cancel: return L.t(.roleCancelHint, language)
        case .send: return L.t(.roleSendHint, language)
        }
    }
}

extension DurationFormat {
    public static func short(_ seconds: TimeInterval, language: AppLanguage) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 1 { return L.t(.durationUnderMinute, language) }
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return L.f(.durationMinutes, language, m)
        case (_, 0): return L.f(.durationHours, language, h)
        default: return L.f(.durationHoursMinutes, language, h, m)
        }
    }
}
