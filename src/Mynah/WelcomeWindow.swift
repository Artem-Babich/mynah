import AVFoundation
import AppKit
import Combine
import MynahCore
import SwiftUI

/// Live statuses behind the Welcome checklist. Permissions are re-read every second while the
/// window is open, so a toggle flipped in System Settings shows up on its own.
@MainActor
final class WelcomeModel: ObservableObject {
    @Published var microphone: PermissionStatus = WelcomeModel.currentMicrophone()
    @Published var accessibility: Bool = Paster.isTrusted
    @Published var model: ModelStatus = .loading(0)
    @Published var accessibilityRequested = false
    /// Fired once when Accessibility flips to granted — the window comes back to the front.
    var onAccessibilityGranted: (() -> Void)?

    var checklist: OnboardingChecklist {
        OnboardingChecklist(microphone: microphone, accessibility: accessibility, model: model)
    }

    func refresh() {
        microphone = Self.currentMicrophone()
        let ax = Paster.isTrusted
        if ax, !accessibility { onAccessibilityGranted?() }
        accessibility = ax
    }

    func requestMicrophone() {
        switch microphone {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Log.info("microphone granted=\(granted)")
                Task { @MainActor in self.refresh() }
            }
        case .denied:
            Self.openPrivacyPane("Privacy_Microphone")
        case .granted:
            break
        }
    }

    func requestAccessibility() {
        accessibilityRequested = true
        Paster.requestAccessibility()  // adds Mynah to the list and offers "Open System Settings"
    }

    static func currentMicrophone() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    let model = WelcomeModel()
    private var window: NSWindow?
    private var timer: Timer?
    private let settings: SettingsModel
    private let openSettings: () -> Void

    init(settings: SettingsModel, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.openSettings = openSettings
        super.init()
        model.onAccessibilityGranted = { [weak self] in self?.bringToFront() }
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 600, height: 720),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.title = ""
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentViewController = NSHostingController(rootView: WelcomeView(
                model: model, settings: settings,
                onOpenSettings: { [weak self] in self?.openSettings() },
                onFinish: { [weak self] in self?.window?.performClose(nil) }))
            w.center()
            window = w
        }
        model.refresh()
        startPolling()
        bringToFront()
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.refresh() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        settings.settings.onboardingCompleted = true
    }
}

// MARK: view

private struct WelcomeView: View {
    @ObservedObject var model: WelcomeModel
    @ObservedObject var settings: SettingsModel
    let onOpenSettings: () -> Void
    let onFinish: () -> Void
    @State private var tryText = ""

    private var lang: AppLanguage { settings.settings.language }
    private var toggle: String { settings.settings.toggleHotkey?.label ?? "—" }

    var body: some View {
        let list = model.checklist
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(.welcomeTitle, lang)).font(.system(size: 24, weight: .bold))
                        Text(L.t(.welcomeSubtitle, lang)).foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    StepRow(number: 1, title: L.t(.stepMicTitle, lang),
                            hint: model.microphone == .denied ? L.t(.stepMicDenied, lang) : L.t(.stepMicHint, lang),
                            state: list.microphoneStep, lang: lang) {
                        Button(model.microphone == .denied ? L.t(.openSystemSettings, lang) : L.t(.stepMicButton, lang)) {
                            model.requestMicrophone()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Divider()
                    StepRow(number: 2, title: L.t(.stepAxTitle, lang),
                            hint: list.accessibilityStep == .locked ? L.t(.stepLockedHint, lang)
                                : model.accessibilityRequested ? L.t(.stepAxWaiting, lang) : L.t(.stepAxHint, lang),
                            state: list.accessibilityStep, lang: lang) {
                        HStack {
                            if model.accessibilityRequested {
                                Button(L.t(.openSystemSettings, lang)) {
                                    WelcomeModel.openPrivacyPane("Privacy_Accessibility")
                                }
                            }
                            Button(L.t(.stepAxButton, lang)) { model.requestAccessibility() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    Divider()
                    StepRow(number: 3, title: L.t(.stepModelTitle, lang), hint: modelHint(list.modelStep),
                            state: list.modelStep, lang: lang) { EmptyView() }
                }
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))

                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t(.howToTitle, lang)).font(.headline)
                    HowToRow(keys: toggle, text: L.t(.howToTap, lang))
                    HowToRow(keys: toggle, text: L.t(.howToHold, lang))
                    HowToRow(keys: settings.settings.cancelHotkey?.label ?? "—", text: L.t(.howToCancel, lang))
                    Text(L.t(.howToMore, lang)).font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(.tryTitle, lang)).font(.headline)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $tryText)
                            .font(.system(size: 14))
                            .frame(height: 90)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                            .disabled(!list.canTry)
                        if tryText.isEmpty {
                            Text(list.canTry ? L.f(.tryPlaceholder, lang, toggle) : L.t(.tryLocked, lang))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12).padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
                }

                HStack {
                    Button(L.t(.welcomeOpenSettings, lang), action: onOpenSettings)
                    Spacer()
                    Button(L.t(.welcomeFinish, lang), action: onFinish)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(width: 600, height: 720)
    }

    private func modelHint(_ state: StepState) -> String {
        if case .failed(let message) = state { return L.f(.stepModelFailed, lang, message) }
        return L.t(.stepModelHint, lang)
    }
}

private struct StepRow<Action: View>: View {
    let number: Int
    let title: String
    let hint: String
    let state: StepState
    let lang: AppLanguage
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            badge
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(hint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 14)
        .opacity(state == .locked ? 0.5 : 1)
    }

    @ViewBuilder private var badge: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 22)).foregroundStyle(.orange)
        default:
            Text("\(number)").font(.system(size: 13, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(state == .locked ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.accentColor)))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch state {
        case .done:
            Text(L.t(.stepDone, lang)).foregroundStyle(.green)
        case .active:
            action()
        case .inProgress(let p):
            HStack(spacing: 8) {
                ProgressView(value: p).frame(width: 110)
                Text("\(Int(p * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        case .locked, .failed:
            EmptyView()
        }
    }
}

private struct HowToRow: View {
    let keys: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            KeyCaps(label: keys).frame(minWidth: 70, alignment: .leading)
            Text(text)
        }
    }
}
