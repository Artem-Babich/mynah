import AppKit
import SwiftUI
import WhisperBarCore

/// The settings window (menu bar → «Настройки…», ⌘,).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsModel
    private let history: HistoryModel

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
            w.title = "WhisperBar — настройки"
            w.isReleasedWhenClosed = false
            w.minSize = CGSize(width: 720, height: 480)
            w.contentViewController = NSHostingController(
                rootView: SettingsView(settings: settings, history: history))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private enum Page: String, CaseIterable, Identifiable {
    case home, vocabulary, shortcuts, sound, configuration
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Главная"
        case .vocabulary: return "Словарь"
        case .shortcuts: return "Горячие клавиши"
        case .sound: return "Звук"
        case .configuration: return "Окно и запуск"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .vocabulary: return "character.book.closed"
        case .shortcuts: return "keyboard"
        case .sound: return "speaker.wave.2"
        case .configuration: return "gearshape"
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var history: HistoryModel
    @State private var page: Page? = .home

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { page in
                Label(page.title, systemImage: page.icon).tag(page)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            switch page ?? .home {
            case .home: HomePage(history: history)
            case .vocabulary: VocabularyPage(model: settings)
            case .shortcuts: ShortcutsPage(model: settings)
            case .sound: SoundPage(model: settings)
            case .configuration: ConfigurationPage(model: settings)
            }
        }
    }
}

// MARK: Home

private struct HomePage: View {
    @ObservedObject var history: HistoryModel
    @State private var copiedID: UUID?

    var body: some View {
        let stats = UsageStats.compute(history.entries)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    StatTile(value: "\(stats.averageWPM)", caption: "слов в минуту")
                    StatTile(value: stats.words.formatted(), caption: "слов всего")
                    StatTile(value: "\(stats.appsUsed)", caption: "приложений")
                    StatTile(value: DurationFormat.short(stats.timeSaved), caption: "сэкономлено vs печать 40 WPM")
                }

                Text("Недавние записи").font(.headline)
                if history.entries.isEmpty {
                    Text("Пока пусто — нажмите \(HotkeyConfig.dictate.label) и скажите что-нибудь.")
                        .foregroundStyle(.secondary)
                }
                LazyVStack(spacing: 10) {
                    ForEach(history.entries) { entry in
                        HistoryCard(entry: entry, copied: copiedID == entry.id)
                            .onTapGesture {
                                Paster.copy(entry.text)
                                copiedID = entry.id
                            }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Главная")
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
    let copied: Bool

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let icon = appIcon {
                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                }
                Text([entry.appName, Self.relative.localizedString(for: entry.date, relativeTo: Date())]
                    .compactMap { $0 }.joined(separator: " · "))
                Spacer()
                Text(copied ? "Скопировано" : "Клик — скопировать")
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.6)))
        .contentShape(Rectangle())
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
        Form {
            Section {
                HStack {
                    TextField("Что распозналось", text: $from)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("На что заменить", text: $to)
                        .onSubmit(add)
                    Button("Добавить", action: add)
                        .disabled(from.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Замены применяются к тексту перед вставкой: без учёта регистра, только целые слова.")
            }

            Section("Замены") {
                if model.settings.replacements.isEmpty {
                    Text("Пока нет замен").foregroundStyle(.secondary)
                }
                ForEach(model.settings.replacements) { rule in
                    HStack {
                        Text(rule.from)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Text(rule.to.isEmpty ? "(удалить)" : rule.to)
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
        .navigationTitle("Словарь")
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
        Form {
            Section("Горячие клавиши") {
                row(.toggle, "Нажать — старт/стоп, удерживать — запись, пока держишь")
                row(.pushToTalk, "Удерживать — запись, отпустить — готово")
                row(.cancel, "Во время записи: отменить без вставки")
                row(.send, "Во время записи: вставить текст и нажать Return")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Горячие клавиши")
    }

    private func row(_ role: HotkeyRole, _ subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(role.title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ShortcutField(role: role, model: model)
        }
        .padding(.vertical, 2)
    }
}

// MARK: Sound

private struct SoundPage: View {
    @ObservedObject var model: SettingsModel
    @State private var devices: [AudioDevices.Input] = []

    var body: some View {
        Form {
            Section("Звуковые эффекты") {
                Picker("Набор", selection: $model.settings.soundTheme) {
                    Text("Системные").tag(SoundTheme.system)
                    Text("Мягкие").tag(SoundTheme.soft)
                    Text("Выкл").tag(SoundTheme.off)
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

            Section("Запись") {
                Picker("Микрофон", selection: $model.settings.inputDeviceUID) {
                    Text("Системный (по умолчанию)").tag(String?.none)
                    ForEach(devices) { device in
                        Text(device.name).tag(Optional(device.uid))
                    }
                    if let uid = model.settings.inputDeviceUID, !devices.contains(where: { $0.uid == uid }) {
                        Text("Отключён — используется системный").tag(Optional(uid))
                    }
                }
                Picker("Музыка во время записи", selection: $model.settings.mediaWhileRecording) {
                    Text("Ставить на паузу").tag(MediaBehavior.pause)
                    Text("Ничего не делать").tag(MediaBehavior.nothing)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Звук")
        .onAppear { devices = AudioDevices.inputs() }
    }

    private func preview() {
        SoundPlayer.play(.start, settings: model.settings)
    }
}

// MARK: Configuration

private struct ConfigurationPage: View {
    @ObservedObject var model: SettingsModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Окно записи") {
                Picker("Во время записи показывать", selection: $model.settings.recordingWindow) {
                    Text("Живой бар").tag(RecordingWindowStyle.bar)
                    Text("Без окна").tag(RecordingWindowStyle.none)
                }
                .pickerStyle(.segmented)
            }

            Section("Приложение") {
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        loginError = LaunchAtLogin.set(enabled)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("Открыть лог") { NSWorkspace.shared.open(Log.url) }
                    Button("Открыть папку данных") { NSWorkspace.shared.open(AppPaths.support) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Окно и запуск")
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
