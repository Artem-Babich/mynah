import AppKit
import SwiftUI
import MynahCore

/// Shows a role's shortcut and lets the user record a new one.
/// While recording, global hotkeys are paused (so pressing ⌥W doesn't start a dictation).
struct ShortcutField: View {
    let role: HotkeyRole
    @ObservedObject var model: SettingsModel

    @State private var capturing = false
    @State private var problem: String?
    @State private var monitor: Any?

    private var current: Hotkey? { model.settings.hotkey(for: role) }
    private var defaultValue: Hotkey? { AppSettings().hotkey(for: role) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                if capturing {
                    Text(L.t(.shortcutPress))
                        .foregroundStyle(.secondary)
                } else if let current {
                    KeyCaps(label: current.label)
                } else {
                    Text(L.t(.shortcutNotSet)).foregroundStyle(.tertiary)
                }

                Button(capturing ? L.t(.shortcutCancel) : L.t(.shortcutChange)) {
                    capturing ? stopCapture() : startCapture()
                }

                if current != defaultValue {
                    Button {
                        problem = nil
                        model.settings.setHotkey(defaultValue, for: role)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(L.t(.shortcutReset))
                }
            }
            if let problem {
                Text(problem).font(.caption).foregroundStyle(.orange)
            }
        }
        .onDisappear { stopCapture() }
    }

    private func startCapture() {
        problem = nil
        capturing = true
        model.isCapturingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil  // swallow: don't type into anything while recording a shortcut
        }
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 51, flags.isDisjoint(with: [.command, .option, .control, .shift]) {
            model.settings.setHotkey(nil, for: role)
            stopCapture()
            return
        }
        let hotkey = Hotkey(keyCode: Int(event.keyCode), modifiers: Self.carbonModifiers(flags))
        if let issue = HotkeyValidation.problem(for: hotkey, role: role, in: model.settings) {
            problem = "\(hotkey.label): \(issue)"
            return  // keep capturing
        }
        problem = nil
        model.settings.setHotkey(hotkey, for: role)
        stopCapture()
    }

    private func stopCapture() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if capturing { model.isCapturingShortcut = false }
        capturing = false
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var mask = 0
        if flags.contains(.command) { mask |= KeyNames.cmd }
        if flags.contains(.shift) { mask |= KeyNames.shift }
        if flags.contains(.option) { mask |= KeyNames.option }
        if flags.contains(.control) { mask |= KeyNames.control }
        return mask
    }
}

/// "⌥⇧K" rendered as separate key caps.
struct KeyCaps: View {
    let label: String

    private var parts: [String] {
        var result: [String] = []
        var rest = Substring(label)
        while let first = rest.first, "⌃⌥⇧⌘".contains(first) {
            result.append(String(first))
            rest = rest.dropFirst()
        }
        if !rest.isEmpty { result.append(String(rest)) }
        return result
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
            }
        }
    }
}
