# WhisperBar — functional requirements

Personal local dictation app for macOS (superwhisper-style), built from scratch.

## Recognition
- R1. Speech is recognised fully on-device with NVIDIA Parakeet TDT 0.6b v3 (multilingual, incl. Russian and English) via FluidAudio/CoreML. No network after the first model download.
- R2. Model is the open CC-BY-4.0 conversion (`FluidInference/parakeet-tdt-0.6b-v3-coreml`). The Argmax Pro bundle shipped inside superwhisper must NOT be used (proprietary, NDA).
- R3. Language is auto-detected (no fixed language hint).

## Hotkey
- R4. Dictation hotkey is **⌥W** (Option+W).
- R5. Hold ⌥W ≥ 0.4 s → push-to-talk: release stops recording.
- R6. Tap ⌥W (< 0.4 s) → toggle: recording continues hands-free until the next ⌥W press.
- R7. Esc while recording cancels: nothing is transcribed or pasted. Esc is only captured while recording.
- R8. Hotkey works system-wide without Accessibility permission.

## Output
- R9. Recognised text is pasted into the frontmost app (clipboard + ⌘V); the previous clipboard contents are restored afterwards unless something else changed the clipboard meanwhile.
- R10. Text is cleaned before paste: trimmed, whitespace collapsed, `<unk>` markers removed; empty result → nothing pasted.
- R11. Recordings shorter than 0.3 s are discarded (accidental presses).
- R12. Without Accessibility permission the text stays on the clipboard and the menu shows a warning.

## Menu bar
- R13. Menu-bar only app (no Dock icon). Icon reflects state: loading / ready / recording (red) / transcribing (blue) / error (orange).
- R14. Short sounds on start (Tink), stop (Pop), cancel (Funk).
- R15. Menu shows the 10 latest dictations; clicking one copies it.
- R16. Menu links: open history JSON, open log, grant Accessibility (when missing), reset error, quit.

## Live bar (overlay)
- R19. While recording, a floating bar appears at the **top-centre** of the screen under the mouse cursor. It never takes focus or mouse clicks, so the text still pastes into the app you were in.
- R20. The bar shows live text, a mic level meter and an m:ss timer. Before any text arrives it shows «Говорите… (Esc — отмена)».
- R20a. The bar is 720 px wide and grows downwards with the text (top edge fixed), up to half of the visible screen; beyond that the text auto-scrolls so the newest words stay visible. (Replaces the earlier 2-line «…tail» display, 2026-11-25.)
- R21. Live text comes from FluidAudio's sliding-window streaming (Parakeet v3), window 4 s left / 1 s chunk / 0.5 s right: first words after ~1.5 s, updates every ~1 s. It is a **preview only**: the pasted text still comes from the full batch pass (R1).
- R22. After stop, the bar shows «Распознавание…», then hides as soon as the text is pasted. Cancel (Esc), too-short recordings and errors hide it immediately.

## Media while dictating
- R23. When recording starts and some app is playing media (Chrome, Spotify, Music…, i.e. the system "Now Playing" app), it is paused.
- R24. On release / stop / Esc the media resumes right away, but only if WhisperBar paused it and it is still paused (if I resumed it myself during the recording, WhisperBar does nothing). If nothing was playing, nothing is started.
- R25. Detection and control use the vendored `mediaremote-adapter` (BSD-3, `vendor/`, runs via `/usr/bin/perl` because macOS 15.4+ blocks MediaRemote for third-party apps). If it stops working on a future macOS, dictation keeps working without pause/resume.

## History & logs
- R17. Every dictation is stored newest-first in `~/Library/Application Support/WhisperBar/history.json`, capped at 500 entries; survives restarts; a corrupted file never blocks startup.
- R18. Log file: `~/Library/Logs/WhisperBar/WhisperBar.log`.

## Out of MVP (next stages)
- Modes with LLM post-processing, custom vocabulary, meeting recording, configurable hotkey UI, launch at login.
