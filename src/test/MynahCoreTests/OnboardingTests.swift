// User story: on first launch Mynah opens a "Welcome" checklist instead of firing two system
// permission prompts at once (the second one used to hide behind other windows). I grant
// permissions one at a time, in order: Microphone first, then Accessibility. Each row shows a
// live ✅ when done; the next row unlocks only after the previous one is done. The speech model
// downloads meanwhile and shows its progress. When everything is ready I can try dictation right
// in the window. The window comes back on its own if a permission goes missing, and is always
// available from the menu ("How to use…").

import Foundation
import Testing
@testable import MynahCore

@Suite("Welcome checklist")
struct OnboardingTests {
    private func state(mic: PermissionStatus = .notDetermined, ax: Bool = false, model: ModelStatus = .loading(0.3))
        -> OnboardingChecklist {
        OnboardingChecklist(microphone: mic, accessibility: ax, model: model)
    }

    @Test("on a fresh install only the Microphone step is actionable; Accessibility waits for it")
    func micFirst() {
        let s = state()
        #expect(s.microphoneStep == .active)
        #expect(s.accessibilityStep == .locked)
        #expect(!s.canTry)
    }

    @Test("after Microphone is granted, the Accessibility step becomes actionable")
    func accessibilityAfterMic() {
        let s = state(mic: .granted)
        #expect(s.microphoneStep == .done)
        #expect(s.accessibilityStep == .active)
    }

    @Test("if Microphone was denied, its step stays actionable (to open System Settings) and Accessibility stays locked")
    func micDenied() {
        let s = state(mic: .denied)
        #expect(s.microphoneStep == .active)
        #expect(s.accessibilityStep == .locked)
    }

    @Test("the model step shows progress while loading and is done when ready, regardless of permissions")
    func modelStep() {
        #expect(state(model: .loading(0.4)).modelStep == .inProgress(0.4))
        #expect(state(model: .ready).modelStep == .done)
        #expect(state(model: .failed("x")).modelStep == .failed("x"))
    }

    @Test("dictation can be tried only when microphone, accessibility and model are all ready")
    func canTry() {
        #expect(state(mic: .granted, ax: true, model: .ready).canTry)
        #expect(!state(mic: .granted, ax: true, model: .loading(0.9)).canTry)
        #expect(!state(mic: .granted, ax: false, model: .ready).canTry)
    }

    @Test("the window opens at launch on first run, even if permissions already exist")
    func firstRun() {
        #expect(OnboardingChecklist.shouldShowAtLaunch(completed: false, microphone: .granted, accessibility: true))
    }

    @Test("after the checklist was completed, it opens at launch only if a permission is missing")
    func laterLaunches() {
        #expect(!OnboardingChecklist.shouldShowAtLaunch(completed: true, microphone: .granted, accessibility: true))
        #expect(OnboardingChecklist.shouldShowAtLaunch(completed: true, microphone: .denied, accessibility: true))
        #expect(OnboardingChecklist.shouldShowAtLaunch(completed: true, microphone: .granted, accessibility: false))
    }

    @Test("completing the checklist is remembered in settings; older settings files count as not completed")
    func persisted() throws {
        #expect(AppSettings().onboardingCompleted == false)
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"language":"ru"}"#.utf8))
        #expect(old.onboardingCompleted == false)
        var s = AppSettings()
        s.onboardingCompleted = true
        let round = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        #expect(round.onboardingCompleted)
    }
}
