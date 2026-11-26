import Foundation

public enum PermissionStatus: Equatable, Sendable { case notDetermined, denied, granted }
public enum ModelStatus: Equatable, Sendable { case loading(Double), ready, failed(String) }
public enum StepState: Equatable, Sendable { case locked, active, inProgress(Double), done, failed(String) }

/// The Welcome window: permissions one at a time (Microphone → Accessibility), model progress,
/// then "try it". Pure state — the app feeds it live statuses.
public struct OnboardingChecklist: Equatable, Sendable {
    public var microphone: PermissionStatus
    public var accessibility: Bool
    public var model: ModelStatus

    public init(microphone: PermissionStatus, accessibility: Bool, model: ModelStatus) {
        self.microphone = microphone
        self.accessibility = accessibility
        self.model = model
    }

    public var microphoneStep: StepState { microphone == .granted ? .done : .active }

    public var accessibilityStep: StepState {
        if accessibility { return .done }
        return microphone == .granted ? .active : .locked
    }

    public var modelStep: StepState {
        switch model {
        case .loading(let p): return .inProgress(p)
        case .ready: return .done
        case .failed(let message): return .failed(message)
        }
    }

    public var canTry: Bool { microphone == .granted && accessibility && model == .ready }

    public static func shouldShowAtLaunch(completed: Bool, microphone: PermissionStatus, accessibility: Bool) -> Bool {
        !completed || microphone != .granted || !accessibility
    }
}
