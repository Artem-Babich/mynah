import AppKit
import Combine
import SwiftUI
import MynahCore

/// The settings window (menu bar → Settings…, ⌘,).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsModel
    private let history: HistoryModel
    private var languageObserver: AnyCancellable?

    init(settings: SettingsModel, history: HistoryModel) {
        self.settings = settings
        self.history = history
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 820, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            w.title = L.t(.settingsTitle, settings.settings.language)
            w.isReleasedWhenClosed = false
            w.minSize = CGSize(width: 720, height: 480)
            w.contentViewController = NSHostingController(
                rootView: SettingsView(settings: settings, history: history))
            w.center()
            window = w
            languageObserver = settings.$settings.map(\.language).removeDuplicates().sink { [weak w] language in
                w?.title = L.t(.settingsTitle, language)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private enum Page: String, CaseIterable, Identifiable {
    case home, vocabulary, shortcuts, sound, general
    var id: String { rawValue }

    func title(_ lang: AppLanguage) -> String {
        switch self {
        case .home: return L.t(.pageHome, lang)
        case .vocabulary: return L.t(.pageVocabulary, lang)
        case .shortcuts: return L.t(.pageShortcuts, lang)
        case .sound: return L.t(.pageSound, lang)
        case .general: return L.t(.pageGeneral, lang)
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .vocabulary: return "character.book.closed"
        case .shortcuts: return "keyboard"
        case .sound: return "speaker.wave.2"
        case .general: return "gearshape"
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var history: HistoryModel
    @State private var page: Page? = .home

    var body: some View {
        let lang = settings.settings.language
        NavigationSplitView {
            List(Page.allCases, selection: $page) { page in
                Label(page.title(lang), systemImage: page.icon).tag(page)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            switch page ?? .home {
            case .home: HomePage(history: history, lang: lang, toggleLabel: settings.settings.toggleHotkey?.label)
            case .vocabulary: VocabularyPage(model: settings)
            case .shortcuts: ShortcutsPage(model: settings)
            case .sound: SoundPage(model: settings)
            case .general: GeneralPage(model: settings)
            }
        }
        .environment(\.locale, lang.locale)
    }
}

// MARK: Home

private struct HomePage: View {
    @ObservedObject var history: HistoryModel
    let lang: AppLanguage
    let toggleLabel: String?
    @State private var copiedID: UUID?

    var body: some View {
        let stats = UsageStats.compute(history.entries)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    StatTile(value: "\(stats.averageWPM)", caption: L.t(.statWPM, lang))
                    StatTile(value: stats.words.formatted(.number.locale(lang.locale)), caption: L.t(.statWords, lang))
                    StatTile(value: "\(stats.appsUsed)", caption: L.t(.statApps, lang))
                    StatTile(value: DurationFormat.short(stats.timeSaved, language: lang), caption: L.t(.statSaved, lang))
                }

                Text(L.t(.recentRecordings, lang)).font(.headline)
                if history.entries.isEmpty {
                    Text(L.f(.emptyHistory, lang, toggleLabel ?? HotkeyConfig.dictate.label))
                        .foregroundStyle(.secondary)
                }
                LazyVStack(spacing: 10) {
                    ForEach(history.entries) { entry in
                        HistoryCard(entry: entry, lang: lang, copied: copiedID == entry.id)
                            .onTapGesture {
                                Paster.copy(entry.text)
                                copiedID = entry.id
                            }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(L.t(.pageHome, lang))
    }
}

private struct StatTile: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.6)))
    }
}

private struct HistoryCard: View {
    let entry: HistoryEntry
    let lang: AppLanguage
    let copied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let icon = appIcon {
                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                }
                Text([entry.appName, relativeDate].compactMap { $0 }.joined(separator: " · "))
                Spacer()
                Text(copied ? L.t(.copied, lang) : L.t(.clickToCopy, lang))
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.6)))
        .contentShape(Rectangle())
    }

    private var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.locale = lang.locale
        f.unitsStyle = .short
        return f.localizedString(for: entry.date, relativeTo: Date())
    }

    private var appIcon: NSImage? {
        guard let id = entry.appBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: Vocabulary

private struct VocabularyPage: View {
    @ObservedObject var model: SettingsModel
    @State private var from = ""
    @State private var to = ""

    var body: some View {
        let lang = model.settings.language
        Form {
            Section {
                HStack {
                    TextField(L.t(.vocabFrom, lang), text: $from)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField(L.t(.vocabTo, lang), text: $to)
                        .onSubmit(add)
                    Button(L.t(.vocabAdd, lang), action: add)
                        .disabled(from.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text(L.t(.vocabFooter, lang))
            }

            Section(L.t(.vocabHeader, lang)) {
                if model.settings.replacements.isEmpty {
                    Text(L.t(.vocabEmpty, lang)).foregroundStyle(.secondary)
                }
                ForEach(model.settings.replacements) { rule in
                    HStack {
                        Text(rule.from)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Text(rule.to.isEmpty ? L.t(.vocabDeleteMarker, lang) : rule.to)
                        Spacer()
                        Button(role: .destructive) {
                            model.settings.replacements.removeAll { $0.id == rule.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L.t(.pageVocabulary, lang))
    }

    private func add() {
        let f = from.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { return }
        model.settings.replacements.append(Replacement(from: f, to: to.trimmingCharacters(in: .whitespaces)))
        from = ""
        to = ""
    }
}

// MARK: Shortcuts

private struct ShortcutsPage: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let lang = model.settings.language
        Form {
            Section(L.t(.shortcutsHeader, lang)) {
                ForEach(HotkeyRole.allCases, id: \.self) { role in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(role.title(lang))
                            Text(role.hint(lang)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ShortcutField(role: role, model: model)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L.t(.pageShortcuts, lang))
    }
}

// MARK: Sound

private struct SoundPage: View {
    @ObservedObject var model: SettingsModel
    @State private var devices: [AudioDevices.Input] = []

    var body: some View {
        let lang = model.settings.language
        Form {
            Section(L.t(.soundEffects, lang)) {
                Picker(L.t(.soundSet, lang), selection: $model.settings.soundTheme) {
                    Text(L.t(.themeSystem, lang)).tag(SoundTheme.system)
                    Text(L.t(.themeSoft, lang)).tag(SoundTheme.soft)
                    Text(L.t(.themeOff, lang)).tag(SoundTheme.off)
                }
                .pickerStyle(.segmented)
                .onChange(of: model.settings.soundTheme) { _, _ in preview() }

                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $model.settings.soundVolume, in: 0...1) { editing in
                        if !editing { preview() }
                    }
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                .disabled(model.settings.soundTheme == .off)
            }

            Section(L.t(.recordingSection, lang)) {
                Picker(L.t(.microphone, lang), selection: $model.settings.inputDeviceUID) {
                    Text(L.t(.microphoneDefault, lang)).tag(String?.none)
                    ForEach(devices) { device in
                        Text(device.name).tag(Optional(device.uid))
                    }
                    if let uid = model.settings.inputDeviceUID, !devices.contains(where: { $0.uid == uid }) {
                        Text(L.t(.microphoneMissing, lang)).tag(Optional(uid))
                    }
                }
                Picker(L.t(.mediaWhileRecording, lang), selection: $model.settings.mediaWhileRecording) {
                    Text(L.t(.mediaPause, lang)).tag(MediaBehavior.pause)
                    Text(L.t(.mediaNothing, lang)).tag(MediaBehavior.nothing)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L.t(.pageSound, lang))
        .onAppear { devices = AudioDevices.inputs() }
    }

    private func preview() {
        SoundPlayer.play(.start, settings: model.settings)
    }
}

// MARK: General

private struct GeneralPage: View {
    @ObservedObject var model: SettingsModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        let lang = model.settings.language
        Form {
            Section {
                Picker(L.t(.language, lang), selection: $model.settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L.t(.recordingWindowSection, lang)) {
                Picker(L.t(.recordingWindowLabel, lang), selection: $model.settings.recordingWindow) {
                    Text(L.t(.windowBar, lang)).tag(RecordingWindowStyle.bar)
                    Text(L.t(.windowNone, lang)).tag(RecordingWindowStyle.none)
                }
                .pickerStyle(.segmented)
            }

            Section(L.t(.applicationSection, lang)) {
                Toggle(L.t(.launchAtLogin, lang), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        loginError = LaunchAtLogin.set(enabled)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button(L.t(.openLog, lang)) { NSWorkspace.shared.open(Log.url) }
                    Button(L.t(.openDataFolder, lang)) { NSWorkspace.shared.open(AppPaths.support) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L.t(.pageGeneral, lang))
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
