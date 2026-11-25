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

## History & logs
- R17. Every dictation is stored newest-first in `~/Library/Application Support/WhisperBar/history.json`, capped at 500 entries; survives restarts; a corrupted file never blocks startup.
- R18. Log file: `~/Library/Logs/WhisperBar/WhisperBar.log`.

## Out of MVP (next stages)
- Modes with LLM post-processing, custom vocabulary, meeting recording, configurable hotkey UI, launch at login.
