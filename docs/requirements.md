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

## Settings window (2026-11-25)
- R26. Menu bar → «Настройки…» (⌘,) opens a settings window with pages: Главная, Словарь, Горячие клавиши, Звук, Окно и запуск. Every change applies immediately and is saved to `~/Library/Application Support/WhisperBar/settings.json`. Defaults reproduce the behaviour above (R4–R7, R14, R19, R23). A corrupted or older settings file never blocks startup: missing values fall back to defaults.
- R27. **Горячие клавиши**: four rebindable shortcuts — «Запись» (tap = toggle, hold = push-to-talk; default ⌥W — R4–R6), «Push to Talk» (hold to record, release to stop; default none), «Отмена» (default Esc — R7), «Отправить» (during a recording: paste + press Return; default none). Record by pressing the combo, ⌫ clears, ↺ restores the default. Global hotkeys are paused while recording a combo.
- R28. Always-on shortcuts (Запись, Push to Talk) need a modifier or an F-key; a combo already used by another action is rejected with its name. Отмена/Отправить may be bare keys because they are captured only while recording. A shortcut owned by another app is shown as a warning in the menu.
- R29. **Звук**: sound set Системные (Tink/Pop/Funk) / Мягкие (Morse/Purr/Bottle) / Выкл, volume slider (preview on change); microphone picker (system default or a specific device; a missing device falls back to the default); «Музыка во время записи»: Ставить на паузу (R23–R24) / Ничего не делать.
- R30. **Окно и запуск**: recording window Живой бар / Без окна (no bar, no live preview); «Запускать при входе в систему» (macOS login items); buttons to open the log and the data folder.
- R31. **Словарь**: replacements «что распозналось → на что заменить», applied to the final text before paste — case-insensitive, whole words only, any language; an empty target deletes the phrase.
- R32. **Главная**: stats over the whole history — words, average speed (WPM over speaking time), apps used, time saved vs typing at 40 WPM — and all recent dictations with the target app's icon/name and relative time; click copies the text. History entries now store the frontmost app at stop time (older entries load without it).
- R33. The app has a hidden main menu so ⌘C/⌘V/⌘X/⌘A/⌘Z and ⌘W work in the settings window.

## Interface language (2026-11-25)
- R34. The whole interface — menu-bar menu and status, live bar, settings window, shortcut names and validation messages, errors, durations, relative dates — is in **English by default**. Settings → General → Language switches it to **Русский** (and back); the choice is saved, applies immediately without restart, and older settings files open in English. Every text exists in both languages with matching placeholders (enforced by specs).
- R35. Settings page names in English: Home, Vocabulary, Shortcuts, Sound, General (Russian: Главная, Словарь, Горячие клавиши, Звук, Общие). The language picker lives on General. The macOS microphone permission prompt text is English. Russian labels quoted in R26–R32 are the Russian-mode labels.

## Distribution (2026-11-26)
- R36. Users install without cloning: a **signed (Developer ID) and notarized DMG** on GitHub Releases (drag to Applications), or `brew install --cask artem-babich/tap/whisperbar`. Gatekeeper opens it without warnings; the app inside is stapled so it also opens offline after being copied out of the DMG.
- R37. Requirements stated to users: Apple Silicon, macOS 14+. The cask declares the same (`arch: :arm64`, `macos: >= :sonoma`); `zap` removes WhisperBar's settings/history and logs, not the shared FluidAudio model cache.
- R38. Releases come from `scripts/release.sh <version>`: dry run builds, tests, signs, notarizes app + DMG and checks Gatekeeper; `--publish` (only from an up-to-date, clean `main`, new tag) also tags `v<version>`, creates the GitHub Release with the DMG and opens a PR in the tap with the new version/sha256.

## History & logs
- R17. Every dictation is stored newest-first in `~/Library/Application Support/WhisperBar/history.json`, capped at 500 entries; survives restarts; a corrupted file never blocks startup.
- R18. Log file: `~/Library/Logs/WhisperBar/WhisperBar.log`.

## Out of MVP (next stages)
- Modes with LLM post-processing, vocabulary hints for the model (boosting), meeting recording, models library, mouse-button shortcut, auto mic gain, updates.
