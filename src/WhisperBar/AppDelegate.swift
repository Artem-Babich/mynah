import AVFoundation
import AppKit
import WhisperBarCore
import WhisperBarEngine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Status: Equatable {
        case loading(Double), ready, recording, transcribing, error(String)
    }

    private enum HotkeyID {
        static let dictate: UInt32 = 1
        static let cancel: UInt32 = 2
    }

    private var statusItem: NSStatusItem!
    private var hotkeys: GlobalHotkey!
    private var gesture = HotkeyGesture(holdThreshold: 0.4)
    private let recorder = AudioRecorder()
    private let engine = ParakeetEngine()
    private let policy = RecordingPolicy(minimumDuration: 0.3)
    private let history = HistoryStore(fileURL: FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("WhisperBar/history.json"))
    private var status: Status = .loading(0) { didSet { refreshIcon() } }
    private let overlay = OverlayPanel()
    private var liveFactory: LiveSessionFactory?
    private var liveSession: LiveSession?

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("launch")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()

        hotkeys = GlobalHotkey { [weak self] id, pressed in self?.onHotkey(id: id, pressed: pressed) }
        let key = HotkeyConfig.dictate
        if !hotkeys.register(id: HotkeyID.dictate, keyCode: key.keyCode, modifiers: key.modifiers) {
            status = .error("\(key.label) занят другим приложением (superwhisper?)")
        }

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
            await MainActor.run { status = .error("Модель: \(error.localizedDescription)") }
        }
    }

    // MARK: hotkey → actions

    private func onHotkey(id: UInt32, pressed: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        let action: HotkeyAction
        switch (id, pressed) {
        case (HotkeyID.dictate, true): action = gesture.keyDown(at: now)
        case (HotkeyID.dictate, false): action = gesture.keyUp(at: now)
        case (HotkeyID.cancel, true): action = gesture.cancel()
        default: action = .none
        }
        handle(action)
    }

    private func handle(_ action: HotkeyAction) {
        switch action {
        case .start: startRecording()
        case .stop: stopRecording()
        case .cancel: cancelRecording()
        case .none: break
        }
    }

    private func startRecording() {
        guard status != .transcribing, engineReadyOrBeep() else {
            _ = gesture.cancel()
            return
        }
        startLivePreview()
        do {
            try recorder.start()
            overlay.showRecording()
            hotkeys.register(id: HotkeyID.cancel, keyCode: HotkeyConfig.cancel.keyCode,
                             modifiers: HotkeyConfig.cancel.modifiers)
            NSSound(named: "Tink")?.play()
            status = .recording
            Log.info("recording start")
        } catch {
            _ = gesture.cancel()
            endLivePreview()
            Log.info("recording failed: \(error)")
            status = .error("Микрофон: \(error.localizedDescription)")
        }
    }

    private func engineReadyOrBeep() -> Bool {
        if case .loading = status { NSSound.beep(); return false }
        if case .error = status, !recorderCanRetry { NSSound.beep(); return false }
        return true
    }

    /// Mic errors are retryable; model errors are not.
    private var recorderCanRetry: Bool {
        if case .error(let msg) = status { return msg.hasPrefix("Микрофон") }
        return false
    }

    /// Live text + level meter in the bar. The pasted text still comes from the batch pass.
    private func startLivePreview() {
        let session = liveFactory?.start { [weak self] text in
            Task { @MainActor in
                guard let self, self.status == .recording, !text.isEmpty else { return }
                self.overlay.state.text = text
            }
        }
        liveSession = session
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

    private func cancelRecording() {
        _ = recorder.stop()
        endLivePreview()
        overlay.hide()
        hotkeys.unregister(id: HotkeyID.cancel)
        NSSound(named: "Funk")?.play()
        status = .ready
        Log.info("recording cancelled")
    }

    private func stopRecording() {
        let samples = recorder.stop()
        endLivePreview()
        hotkeys.unregister(id: HotkeyID.cancel)
        let duration = RecordingPolicy.duration(sampleCount: samples.count, sampleRate: ParakeetEngine.sampleRate)
        Log.info(String(format: "recording stop %.2fs", duration))
        guard policy.shouldTranscribe(sampleCount: samples.count, sampleRate: ParakeetEngine.sampleRate) else {
            overlay.hide()
            status = .ready
            return
        }
        NSSound(named: "Pop")?.play()
        overlay.showTranscribing()
        status = .transcribing
        Task { await transcribe(samples, duration: duration) }
    }

    private func transcribe(_ samples: [Float], duration: TimeInterval) async {
        do {
            let t0 = Date()
            let raw = try await engine.transcribe(samples: samples)
            let elapsed = Date().timeIntervalSince(t0)
            await MainActor.run {
                Log.info(String(format: "transcribed %.2fs audio in %.2fs, %d chars", duration, elapsed, raw.count))
                overlay.hide()
                guard let text = TranscriptCleaner.clean(raw) else {
                    status = .ready
                    return
                }
                let pasted = Paster.paste(text)
                if !pasted { Log.info("no accessibility — text left on clipboard") }
                try? history.add(HistoryEntry(date: Date(), text: text, audioDuration: duration))
                status = pasted ? .ready : .error("Нет доступа Accessibility — текст в буфере")
            }
        } catch {
            Log.info("transcription failed: \(error)")
            await MainActor.run { overlay.hide(); status = .error("Распознавание: \(error.localizedDescription)") }
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
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "WhisperBar")
        button.image?.isTemplate = tint == nil
        button.contentTintColor = tint
    }

    private var statusText: String {
        switch status {
        case .loading(let p): return p > 0 && p < 1
            ? String(format: "Загрузка модели… %.0f%%", p * 100) : "Загрузка модели…"
        case .ready: return "Готово — \(HotkeyConfig.dictate.label) (зажать или нажать), Esc — отмена"
        case .recording: return "Запись…"
        case .transcribing: return "Распознавание…"
        case .error(let msg): return "⚠️ \(msg)"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: statusText, action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())

        let recent = history.entries.prefix(10)
        if recent.isEmpty {
            menu.addItem(withTitle: "История пуста", action: nil, keyEquivalent: "").isEnabled = false
        } else {
            menu.addItem(withTitle: "Последние (клик — скопировать)", action: nil, keyEquivalent: "").isEnabled = false
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
        addItem(menu, "Открыть историю (JSON)", #selector(openHistory))
        addItem(menu, "Открыть лог", #selector(openLog))
        if !Paster.isTrusted {
            addItem(menu, "Разрешить вставку (Accessibility)…", #selector(openAccessibility))
        }
        if case .error = status { addItem(menu, "Сбросить ошибку", #selector(clearError)) }
        menu.addItem(.separator())
        addItem(menu, "Выход", #selector(quit), key: "q")
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func copyEntry(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String { Paster.copy(text) }
    }

    @objc private func openHistory() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperBar/history.json")
        if FileManager.default.fileExists(atPath: url.path) { NSWorkspace.shared.open(url) }
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
}
