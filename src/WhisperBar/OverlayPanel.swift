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

/// Floating bar at the top-centre of the active screen. Grows downwards with the text up to
/// half the screen, then scrolls to the newest words. Never takes focus or clicks, so the text
/// still pastes into the app you were typing in.
@MainActor
final class OverlayPanel {
    let state = OverlayState()
    private let panel: NSPanel
    private var visibleFrame: CGRect = .zero
    private static let topMargin: CGFloat = 10

    init() {
        let size = CGSize(width: OverlayLayout.width, height: OverlayLayout.minHeight)
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
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

        let blur = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 18
        blur.layer?.masksToBounds = true
        blur.autoresizingMask = [.width, .height]

        let host = NSHostingView(rootView: OverlayView(state: state) { _ in })
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        blur.addSubview(host)
        panel.contentView = blur

        // Set the height callback after init so it can capture self.
        host.rootView = OverlayView(state: state) { [weak self] textHeight in
            self?.fit(textHeight: textHeight)
        }
    }

    func showRecording() {
        state.phase = .recording
        state.text = ""
        state.level = 0
        state.startedAt = Date()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        visibleFrame = screen?.visibleFrame ?? .zero
        setHeight(OverlayLayout.minHeight, animate: false)
        panel.orderFrontRegardless()
    }

    func showTranscribing() {
        state.phase = .transcribing
        state.level = 0
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func fit(textHeight: CGFloat) {
        guard visibleFrame != .zero else { return }
        let height = OverlayLayout.panelHeight(
            textHeight: textHeight, maxHeight: OverlayLayout.maxHeight(visibleFrame: visibleFrame))
        guard abs(height - panel.frame.height) > 0.5 else { return }
        setHeight(height, animate: panel.isVisible)
    }

    private func setHeight(_ height: CGFloat, animate: Bool) {
        let frame = OverlayLayout.frame(
            visibleFrame: visibleFrame, size: CGSize(width: OverlayLayout.width, height: height),
            topMargin: Self.topMargin)
        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct OverlayView: View {
    @ObservedObject var state: OverlayState
    let onTextHeight: (CGFloat) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if state.phase == .recording {
                    LevelMeter(level: state.level)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 34, height: 24)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(displayText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isPlaceholder ? .secondary : .primary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 3)
                            .background(GeometryReader { g in
                                Color.clear.preference(key: TextHeightKey.self, value: g.size.height)
                            })
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .onChange(of: displayText) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            if state.phase == .recording {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text(ElapsedFormat.string(context.date.timeIntervalSince(state.startedAt)))
                        .font(.system(size: 12, weight: .regular).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(height: 24)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, OverlayLayout.verticalPadding / 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(TextHeightKey.self) { onTextHeight($0) }
    }

    private var isPlaceholder: Bool { state.phase == .transcribing || state.text.isEmpty }

    private var displayText: String {
        if state.phase == .transcribing { return "Распознавание…" }
        if state.text.isEmpty { return "Говорите…  (Esc — отмена)" }
        // Safety cap for very long dictations; the panel itself scrolls.
        return LiveTranscript.tail(state.text, maxChars: 4000)
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
