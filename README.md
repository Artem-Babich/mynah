# WhisperBar

Local push-to-talk dictation for macOS. ⌥W → speak → text appears in the active app.
Parakeet TDT v3 (multilingual) on the Neural Engine via [FluidAudio](https://github.com/FluidInference/FluidAudio).

## Build & run
```bash
scripts/build-app.sh          # → build/WhisperBar.app (signed with your Apple Development identity)
open build/WhisperBar.app
```
Build needs Xcode + `cmake` (`brew install cmake`) for the vendored media helper.
First launch: allow **Microphone** and **Accessibility** (System Settings → Privacy & Security).
Model (~470 MB) is cached in `~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3`.

## Use
| Action | Result |
|---|---|
| Hold ⌥W, speak, release | push-to-talk |
| Tap ⌥W, speak, tap ⌥W | hands-free toggle |
| Esc while recording | cancel |

## Dev
```bash
swift test --disable-sandbox                                   # specs in src/test
swift build --disable-sandbox -c release --product whisperbar-cli
.build/release/whisperbar-cli transcribe some.wav              # smoke test without UI
```
Requirements: `docs/requirements.md`. Log: `~/Library/Logs/WhisperBar/WhisperBar.log`.
