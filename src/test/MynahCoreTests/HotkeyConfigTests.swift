// User story: I start dictation with ⌥W (Option+W) — the same muscle memory I have
// from superwhisper — and Esc cancels a recording in progress.

import Testing
@testable import MynahCore

@Suite("Default hotkeys")
struct HotkeyConfigTests {
    @Test("the default dictation hotkey is Option+W")
    func dictateIsOptionW() {
        #expect(HotkeyConfig.dictate.keyCode == 13)      // kVK_ANSI_W
        #expect(HotkeyConfig.dictate.modifiers == 2048)  // optionKey
        #expect(HotkeyConfig.dictate.label == "⌥W")
    }

    @Test("Esc without modifiers cancels a recording")
    func cancelIsEsc() {
        #expect(HotkeyConfig.cancel.keyCode == 53)  // kVK_Escape
        #expect(HotkeyConfig.cancel.modifiers == 0)
    }
}
