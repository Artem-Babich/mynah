// User story: when I record a new shortcut in Settings → Shortcuts, Mynah stops me from
// picking something that would break normal typing (a bare letter as an always-on global hotkey)
// or a combination already used by another action, and tells me why.
// Cancel and Send are only active during a recording, so bare keys like Esc or Return are fine there.

import Testing
@testable import MynahCore

@Suite("Shortcut validation")
struct HotkeyValidationTests {
    private let defaults = AppSettings()

    @Test("an always-on shortcut needs a modifier: a bare letter is rejected")
    func bareLetterRejected() {
        #expect(HotkeyValidation.problem(for: Hotkey(keyCode: 13, modifiers: 0), role: .toggle, in: defaults) != nil)
        #expect(HotkeyValidation.problem(for: Hotkey(keyCode: 13, modifiers: 0), role: .pushToTalk, in: defaults) != nil)
    }

    @Test("an always-on shortcut with a modifier, or a bare F-key, is accepted")
    func modifierOrFKeyAccepted() {
        #expect(HotkeyValidation.problem(for: Hotkey(keyCode: 40, modifiers: 2048 | 512), role: .pushToTalk, in: defaults) == nil)
        #expect(HotkeyValidation.problem(for: Hotkey(keyCode: 96, modifiers: 0), role: .pushToTalk, in: defaults) == nil)
    }

    @Test("Cancel and Send accept bare keys because they only work during a recording")
    func recordingOnlyKeysMayBeBare() {
        #expect(HotkeyValidation.problem(for: Hotkey(keyCode: 36, modifiers: 0), role: .send, in: defaults) == nil)
        #expect(HotkeyValidation.problem(for: Hotkey(keyCode: 53, modifiers: 0), role: .cancel, in: defaults) == nil)
    }

    @Test("a shortcut already used by another action is rejected with that action's name")
    func conflict() {
        let problem = HotkeyValidation.problem(for: HotkeyConfig.dictate, role: .pushToTalk, in: defaults)
        #expect(problem?.contains(HotkeyRole.toggle.title) == true)
        #expect(HotkeyValidation.problem(for: HotkeyConfig.cancel, role: .send, in: defaults) != nil)
    }

    @Test("re-recording the same shortcut for the same action is fine")
    func sameRoleOk() {
        #expect(HotkeyValidation.problem(for: HotkeyConfig.dictate, role: .toggle, in: defaults) == nil)
    }

    @Test("each action's shortcut can be read and changed by role")
    func accessByRole() {
        var s = AppSettings()
        s.setHotkey(Hotkey(keyCode: 96, modifiers: 0), for: .pushToTalk)
        s.setHotkey(nil, for: .cancel)
        #expect(s.hotkey(for: .pushToTalk) == Hotkey(keyCode: 96, modifiers: 0))
        #expect(s.hotkey(for: .cancel) == nil)
        #expect(s.hotkey(for: .toggle) == HotkeyConfig.dictate)
    }
}
