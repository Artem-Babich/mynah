import AppKit
import SwiftUI
import WhisperBarCore

/// State rendered by the live bar.
@MainActor
final class OverlayState: ObservableObject {
    enum Phase { case recording, transcribing }
    @Published var phase: Phase = .recording
    @Published var text = ""
    @Published var level: Float = 0
    @Published var startedAt = Date()
}

/// Floating bar at the top-centre of the active screen. Never takes focus or clicks,
/// so the text still pastes into the app you were typing in.
@MainActor
final class OverlayPanel {
    static let size = CGSize(width: 560, height: 64)

    let state = OverlayState()
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let blur = NSVisualEffectView(frame: CGRect(origin: .zero, size: Self.size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 18
        blur.layer?.masksToBounds = true

        let host = NSHostingView(rootView: OverlayView(state: state))
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        blur.addSubview(host)
        panel.contentView = blur
    }

    func showRecording() {
        state.phase = .recording
        state.text = ""
        state.level = 0
        state.startedAt = Date()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(OverlayLayout.frame(visibleFrame: visible, size: Self.size, topMargin: 10), display: false)
        }
        panel.orderFrontRegardless()
    }

    func showTranscribing() {
        state.phase = .transcribing
        state.level = 0
    }

    func hide() {
        panel.orderOut(nil)
    }
}

private struct OverlayView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if state.phase == .recording {
                    LevelMeter(level: state.level)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 34)

            Text(displayText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(state.text.isEmpty || state.phase == .transcribing ? .secondary : .primary)
                .lineLimit(2)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)

            if state.phase == .recording {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text(ElapsedFormat.string(context.date.timeIntervalSince(state.startedAt)))
                        .font(.system(size: 12, weight: .regular).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(width: OverlayPanel.size.width, height: OverlayPanel.size.height)
    }

    private var displayText: String {
        if state.phase == .transcribing { return "Распознавание…" }
        if state.text.isEmpty { return "Говорите…  (Esc — отмена)" }
        return LiveTranscript.tail(state.text, maxChars: 140)
    }
}

/// Five bars driven by the mic level; the middle ones react most.
private struct LevelMeter: View {
    let level: Float
    private let weights: [CGFloat] = [0.45, 0.75, 1.0, 0.75, 0.45]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(weights.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 4, height: 4 + 20 * CGFloat(level) * weights[i])
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
