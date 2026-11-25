// User story: one global hotkey (⌥W by default) controls dictation in two styles.
// - Push-to-talk: I hold the hotkey while speaking; releasing it stops recording.
// - Toggle: I tap the hotkey once to start, speak hands-free, tap again to stop.
// - Esc cancels the current recording without transcribing or pasting anything.
// A press shorter than the hold threshold counts as a tap; longer counts as a hold.

import Testing
@testable import WhisperBarCore

@Suite("Hotkey gesture: push-to-talk and toggle on one key")
struct HotkeyGestureTests {
    @Test("when idle and the hotkey is pressed, recording starts")
    func pressStartsRecording() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        #expect(g.keyDown(at: 0) == .start)
        #expect(g.isRecording)
    }

    @Test("when the hotkey is held longer than the threshold and released, recording stops (push-to-talk)")
    func holdThenReleaseStops() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0)
        #expect(g.keyUp(at: 1.5) == .stop)
        #expect(!g.isRecording)
    }

    @Test("when the hotkey is tapped quickly, recording keeps going after release (toggle mode)")
    func tapLatchesRecording() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0)
        #expect(g.keyUp(at: 0.1) == .none)
        #expect(g.isRecording)
    }

    @Test("in toggle mode, the next press stops recording and its release does nothing")
    func secondTapStops() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0)
        _ = g.keyUp(at: 0.1)
        #expect(g.keyDown(at: 5) == .stop)
        #expect(!g.isRecording)
        #expect(g.keyUp(at: 5.1) == .none)
        #expect(!g.isRecording)
    }

    @Test("after a full toggle cycle, the next press starts a new recording")
    func newCycleAfterToggle() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0); _ = g.keyUp(at: 0.1)
        _ = g.keyDown(at: 5); _ = g.keyUp(at: 5.1)
        #expect(g.keyDown(at: 10) == .start)
    }

    @Test("a repeated key-down while the key is still held is ignored")
    func autoRepeatIgnored() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0)
        #expect(g.keyDown(at: 0.5) == .none)
        #expect(g.isRecording)
    }

    @Test("Esc while recording cancels it")
    func cancelWhileRecording() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0); _ = g.keyUp(at: 0.1)
        #expect(g.cancel() == .cancel)
        #expect(!g.isRecording)
    }

    @Test("Esc while idle does nothing")
    func cancelWhileIdle() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        #expect(g.cancel() == .none)
    }

    @Test("releasing the hotkey after a cancel during push-to-talk does not trigger anything")
    func releaseAfterCancelIgnored() {
        var g = HotkeyGesture(holdThreshold: 0.4)
        _ = g.keyDown(at: 0)
        _ = g.cancel()
        #expect(g.keyUp(at: 2) == .none)
        #expect(g.keyDown(at: 3) == .start)
    }
}
