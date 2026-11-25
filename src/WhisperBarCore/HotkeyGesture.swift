import Foundation

public enum HotkeyAction: Equatable, Sendable { case start, stop, cancel, none }

/// One hotkey, two styles: hold = push-to-talk, quick tap = toggle (latched).
public struct HotkeyGesture: Sendable {
    private enum State: Sendable {
        case idle
        /// Recording started by the current press; key is still down.
        case pressed(at: TimeInterval)
        /// Tap latched recording; key is up, waiting for the stopping press.
        case latched
        /// Key is down but must be ignored until released (after stop/cancel).
        case swallowRelease
    }

    private let holdThreshold: TimeInterval
    private var state: State = .idle

    public init(holdThreshold: TimeInterval = 0.4) {
        self.holdThreshold = holdThreshold
    }

    public var isRecording: Bool {
        switch state {
        case .pressed, .latched: return true
        case .idle, .swallowRelease: return false
        }
    }

    public mutating func keyDown(at time: TimeInterval) -> HotkeyAction {
        switch state {
        case .idle:
            state = .pressed(at: time)
            return .start
        case .latched:
            state = .swallowRelease
            return .stop
        case .pressed, .swallowRelease:
            return .none
        }
    }

    public mutating func keyUp(at time: TimeInterval) -> HotkeyAction {
        switch state {
        case .pressed(let pressedAt):
            if time - pressedAt >= holdThreshold {
                state = .idle
                return .stop
            }
            state = .latched
            return .none
        case .swallowRelease:
            state = .idle
            return .none
        case .idle, .latched:
            return .none
        }
    }

    public mutating func cancel() -> HotkeyAction {
        switch state {
        case .pressed:
            state = .swallowRelease
            return .cancel
        case .latched:
            state = .idle
            return .cancel
        case .idle, .swallowRelease:
            return .none
        }
    }
}
