import AVFoundation
import AppKit
import Combine
import MynahCore
import MynahEngine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Status: Equatable {
        case loading(Double), ready, recording, transcribing, error(ErrorKind, String)
    }

    private enum ErrorKind: Equatable {
        case model, microphone, accessibility, transcription
    }

    private enum HotkeyID {
        static let toggle: UInt32 = 1
        static let cancel: UInt32 = 2
        static let pushToTalk: UInt32 = 3
        static let send: UInt32 = 4
    }

    private var statusItem: NSStatusItem!
    private var hotkeys: GlobalHotkey!
    private var gesture = HotkeyGesture(holdThreshold: 0.4)
    private let recorder = AudioRecorder()
    private let engine = ParakeetEngine()
    private let policy = RecordingPolicy(minimumDuration: 0.3)
    private let settingsModel = SettingsModel()
    private let historyModel = HistoryModel()
    private lazy var settingsWindow = SettingsWindowController(settings: settingsModel, history: historyModel)
    private var status: Status = .loading(0) { didSet { refreshIcon() } }
    private let overlay = OverlayPanel()
    private let media = MediaController()
    private var liveFactory: LiveSessionFactory?
    private var liveSession: LiveSession?
    /// Media was handed to MediaController for this recording (setting is read once at start).
    private var mediaEngaged = false
    /// Always-on hotkeys that another app already owns.
    private var hotkeyWarning: String?
    private var cancellables = Set<AnyCancellable>()

    private var settings: AppSettings { settingsModel.settings }

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("launch")
        L.current = settings.language
        NSApp.mainMenu = Self.makeMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()

        hotkeys = GlobalHotkey { [weak self] id, pressed in self?.onHotkey(id: id, pressed: pressed) }
        registerAlwaysOnHotkeys(settings, capturing: false)

        // @Published emits the NEW value before the property changes, so use the emitted value.
        settingsModel.$settings
            .dropFirst()
            .map { [$0.toggleHotkey, $0.pushToTalkHotkey] }
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.registerAlwaysOnHotkeys(self.settings, capturing: self.settingsModel.isCapturingShortcut)
                }
            }
            .store(in: &cancellables)
        settingsModel.$settings
            .dropFirst()
            .map(\.language)
            .removeDuplicates()
            .sink { language in
                L.current = language
                NSApp.mainMenu = Self.makeMainMenu()
            }
            .store(in: &cancellables)
        settingsModel.$isCapturingShortcut
            .dropFirst()
            .sink { [weak self] capturing in
                guard let self else { return }
                self.registerAlwaysOnHotkeys(self.settings, capturing: capturing)
            }
            .store(in: &cancellables)

        AVCaptureDevice.requestAccess(for: .audio) { granted in Log.info("microphone granted=\(granted)") }
        if !Paster.isTrusted { Paster.requestAccessibility() }

        Task { await loadModel() }
    }

    private func loadModel() async {
        do {
            let t0 = Date()
            try await engine.load { [weak self] p in
                Task { @MainActor in self?.status = .loading(p) }
            }
            Log.info(String(format: "model loaded in %.1fs", Date().timeIntervalSince(t0)))
            let factory = await engine.liveSessions
            await MainActor.run {
                liveFactory = factory
                status = .ready
            }
        } catch {
            Log.info("model load failed: \(error)")
            await MainActor.run { status = .error(.model, error.localizedDescription) }
        }
    }

    // MARK: hotkeys

    /// Toggle + push-to-talk are always on (paused while a shortcut is being recorded in Settings).
    private func registerAlwaysOnHotkeys(_ s: AppSettings, capturing: Bool) {
        hotkeys.unregister(id: HotkeyID.toggle)
        hotkeys.unregister(id: HotkeyID.pushToTalk)
        guard !capturing else { return }
        var taken: [String] = []
        for (id, key) in [(HotkeyID.toggle, s.toggleHotkey), (HotkeyID.pushToTalk, s.pushToTalkHotkey)] {
            guard let key else { continue }
            if !hotkeys.register(id: id, keyCode: key.keyCode, modifiers: key.modifiers) { taken.append(key.label) }
        }
        hotkeyWarning = taken.isEmpty ? nil : taken.joined(separator: ", ")
        Log.info("hotkeys: toggle=\(s.toggleHotkey?.label ?? "-") ptt=\(s.pushToTalkHotkey?.label ?? "-") taken=\(taken)")
    }

    /// Cancel + Send exist only while recording, so bare keys like Esc don't hijack typing.
    private func registerRecordingHotkeys() {
        if let key = settings.cancelHotkey {
            hotkeys.register(id: HotkeyID.cancel, keyCode: key.keyCode, modifiers: key.modifiers)
        }
        if let key = settings.sendHotkey {
            hotkeys.register(id: HotkeyID.send, keyCode: key.keyCode, modifiers: key.modifiers)
        }
    }

    private func unregisterRecordingHotkeys() {
        hotkeys.unregister(id: HotkeyID.cancel)
        hotkeys.unregister(id: HotkeyID.send)
    }

    private func onHotkey(id: UInt32, pressed: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        let action: HotkeyAction
        switch (id, pressed) {
        case (HotkeyID.toggle, true): action = gesture.keyDown(at: now)
        case (HotkeyID.toggle, false): action = gesture.keyUp(at: now)
        case (HotkeyID.pushToTalk, true): action = gesture.pushToTalkDown()
        case (HotkeyID.pushToTalk, false): action = gesture.pushToTalkUp()
        case (HotkeyID.cancel, true): action = gesture.cancel()
        case (HotkeyID.send, true): action = gesture.send()
        default: action = .none
        }
        handle(action)
    }

    private func handle(_ action: HotkeyAction) {
        switch action {
        case .start: startRecording()
        case .stop: stopRecording(send: false)
        case .send: stopRecording(send: true)
        case .cancel: cancelRecording()
        case .none: break
        }
    }

    // MARK: recording

    private func startRecording() {
        guard status != .transcribing, engineReadyOrBeep() else {
            _ = gesture.cancel()
            return
        }
        startLivePreview()
        do {
            try recorder.start(deviceUID: settings.inputDeviceUID)
            if settings.recordingWindow == .bar { overlay.showRecording() }
            mediaEngaged = settings.mediaWhileRecording == .pause
            if mediaEngaged { media.recordingStarted() }
            registerRecordingHotkeys()
            SoundPlayer.play(.start, settings: settings)
            status = .recording
            Log.info("recording start")
        } catch {
            _ = gesture.cancel()
            endLivePreview()
            Log.info("recording failed: \(error)")
            status = .error(.microphone, error.localizedDescription)
        }
    }

    private func engineReadyOrBeep() -> Bool {
        if case .loading = status { NSSound.beep(); return false }
        if case .error = status, !recorderCanRetry { NSSound.beep(); return false }
        return true
    }

    /// Mic errors are retryable; model errors are not.
    private var recorderCanRetry: Bool {
        if case .error(.microphone, _) = status { return true }
        return false
    }

    /// Live text + level meter in the bar. The pasted text still comes from the batch pass.
    private func startLivePreview() {
        let showBar = settings.recordingWindow == .bar
        let session = showBar ? liveFactory?.start { [weak self] text in
            Task { @MainActor in
                guard let self, self.status == .recording, !text.isEmpty else { return }
                self.overlay.state.text = text
            }
        } : nil
        liveSession = session
        guard showBar else { return }
        recorder.onChunk = { [weak self] buffer, chunk in
            session?.feed(buffer)
            let level = AudioLevel.normalized(samples: Array(chunk))
            Task { @MainActor in self?.overlay.state.level = level }
        }
    }

    private func endLivePreview() {
        recorder.onChunk = nil
        if let session = liveSession { Task { await session.stop() } }
        liveSession = nil
    }

    private func releaseMedia() {
        if mediaEngaged { media.recordingEnded() }
        mediaEngaged = false
    }

    private func cancelRecording() {
        _ = recorder.stop()
        releaseMedia()
        endLivePreview()
        overlay.hide()
        unregisterRecordingHotkeys()
        SoundPlayer.play(.cancel, settings: settings)
        status = .ready
        Log.info("recording cancelled")
    }

    private func stopRecording(send: Bool) {
        let samples = recorder.stop()
        releaseMedia()
        endLivePreview()
        unregisterRecordingHotkeys()
        let targetApp = NSWorkspace.shared.frontmostApplication
        let duration = RecordingPolicy.duration(sampleCount: samples.count, sampleRate: ParakeetEngine.sampleRate)
        Log.info(String(format: "recording stop %.2fs send=%@", duration, send ? "yes" : "no"))
        guard policy.shouldTranscribe(sampleCount: samples.count, sampleRate: ParakeetEngine.sampleRate) else {
            overlay.hide()
            status = .ready
            return
        }
        SoundPlayer.play(.stop, settings: settings)
        overlay.showTranscribing()
        status = .transcribing
        Task { await transcribe(samples, duration: duration, send: send, targetApp: targetApp) }
    }

    private func transcribe(_ samples: [Float], duration: TimeInterval, send: Bool, targetApp: NSRunningApplication?) async {
        do {
            let t0 = Date()
            let raw = try await engine.transcribe(samples: samples)
            let elapsed = Date().timeIntervalSince(t0)
            await MainActor.run {
                Log.info(String(format: "transcribed %.2fs audio in %.2fs, %d chars", duration, elapsed, raw.count))
                overlay.hide()
                guard let cleaned = TranscriptCleaner.clean(raw),
                      let text = TranscriptCleaner.clean(VocabularyReplacer.apply(cleaned, settings.replacements))
                else {
                    status = .ready
                    return
                }
                let pasted = Paster.paste(text, pressReturn: send)
                if !pasted { Log.info("no accessibility — text left on clipboard") }
                historyModel.add(HistoryEntry(
                    date: Date(), text: text, audioDuration: duration,
                    appBundleID: targetApp?.bundleIdentifier, appName: targetApp?.localizedName))
                status = pasted ? .ready : .error(.accessibility, "")
            }
        } catch {
            Log.info("transcription failed: \(error)")
            await MainActor.run { overlay.hide(); status = .error(.transcription, error.localizedDescription) }
        }
    }

    // MARK: menu bar UI

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let (symbol, tint): (String, NSColor?) = {
            switch status {
            case .loading: return ("arrow.down.circle", nil)
            case .ready: return ("mic", nil)
            case .recording: return ("mic.fill", .systemRed)
            case .transcribing: return ("waveform", .systemBlue)
            case .error: return ("exclamationmark.triangle", .systemOrange)
            }
        }()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Mynah")
        button.image?.isTemplate = tint == nil
        button.contentTintColor = tint
    }

    private var statusText: String {
        switch status {
        case .loading(let p): return p > 0 && p < 1
            ? L.f(.loadingModelPercent, L.current, Int(p * 100)) : L.t(.loadingModel)
        case .ready:
            let keys = [settings.toggleHotkey.map { L.f(.tapOrHold, L.current, $0.label) },
                        settings.pushToTalkHotkey.map { L.f(.holdOnly, L.current, $0.label) }].compactMap { $0 }
            return keys.isEmpty ? L.t(.readyNoHotkey) : L.f(.ready, L.current, keys.joined(separator: ", "))
        case .recording: return L.t(.recording)
        case .transcribing: return L.t(.transcribing)
        case .error(let kind, let detail):
            switch kind {
            case .model: return "⚠️ " + L.f(.errModel, L.current, detail)
            case .microphone: return "⚠️ " + L.f(.errMicrophone, L.current, detail)
            case .accessibility: return "⚠️ " + L.t(.errNoAccessibility)
            case .transcription: return "⚠️ " + L.f(.errTranscription, L.current, detail)
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: statusText, action: nil, keyEquivalent: "").isEnabled = false
        if let hotkeyWarning {
            menu.addItem(withTitle: "⚠️ " + L.f(.hotkeyTaken, L.current, hotkeyWarning), action: nil, keyEquivalent: "")
                .isEnabled = false
        }
        menu.addItem(.separator())

        let recent = historyModel.entries.prefix(10)
        if recent.isEmpty {
            menu.addItem(withTitle: L.t(.historyEmpty), action: nil, keyEquivalent: "").isEnabled = false
        } else {
            menu.addItem(withTitle: L.t(.recentHeader), action: nil, keyEquivalent: "").isEnabled = false
            for entry in recent {
                let title = entry.text.count > 60 ? String(entry.text.prefix(60)) + "…" : entry.text
                let item = NSMenuItem(title: title, action: #selector(copyEntry(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.text
                item.toolTip = entry.text
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        addItem(menu, L.t(.menuSettings), #selector(openSettings), key: ",")
        addItem(menu, L.t(.menuOpenHistory), #selector(openHistory))
        addItem(menu, L.t(.menuOpenLog), #selector(openLog))
        if !Paster.isTrusted {
            addItem(menu, L.t(.menuGrantAccessibility), #selector(openAccessibility))
        }
        if case .error = status { addItem(menu, L.t(.menuResetError), #selector(clearError)) }
        menu.addItem(.separator())
        addItem(menu, L.t(.menuQuit), #selector(quit), key: "q")
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func copyEntry(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String { Paster.copy(text) }
    }

    @objc private func openSettings() { settingsWindow.show() }

    @objc private func openHistory() {
        if FileManager.default.fileExists(atPath: AppPaths.history.path) { NSWorkspace.shared.open(AppPaths.history) }
    }

    @objc private func openLog() { NSWorkspace.shared.open(Log.url) }

    @objc private func openAccessibility() {
        Paster.requestAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func clearError() {
        Task {
            if await engine.isReady {
                await MainActor.run { status = .ready }
            } else {
                await MainActor.run { status = .loading(0) }
                await loadModel()
            }
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    /// Menu-bar apps have no visible main menu, but text fields in Settings still need
    /// ⌘C/⌘V/⌘X/⌘A/⌘Z and ⌘W to close the window — those come from the (hidden) main menu.
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L.t(.menuCloseWindow), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: L.t(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: L.t(.menuEdit))
        edit.addItem(withTitle: L.t(.menuUndo), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L.t(.menuRedo), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L.t(.menuCut), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L.t(.menuCopy), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L.t(.menuPaste), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L.t(.menuSelectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }
}
