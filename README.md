# WhisperBar

Local push-to-talk dictation for macOS. ⌥W → speak → text appears in the active app.
Parakeet TDT v3 (multilingual) on the Neural Engine via [FluidAudio](https://github.com/FluidInference/FluidAudio).

## Install
Requires a Mac with **Apple Silicon** and **macOS 14 Sonoma** or later.

**Homebrew**
```bash
brew install --cask artem-babich/tap/whisperbar
```

**Or download**: get `WhisperBar-x.y.z.dmg` from [the latest release](https://github.com/Artem-Babich/whisperbar/releases/latest), open it and drag WhisperBar to Applications. The app is signed and notarized by Apple.

**First launch**
1. Allow **Microphone** when asked.
2. Allow **Accessibility** (System Settings → Privacy & Security → Accessibility → WhisperBar) — needed to paste the text.
3. The speech model (~470 MB) downloads once; the menu-bar icon shows progress. After that everything runs offline.

## Build from source
```bash
scripts/build-app.sh          # → build/WhisperBar.app (signed with your Apple Development identity)
open build/WhisperBar.app
```
Build needs Xcode + `cmake` (`brew install cmake`) for the vendored media helper.
Model is cached in `~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3`.

## Use
Menu bar → **Settings…** (⌘,): interface language (English / Русский), shortcuts, sounds, microphone, media pause, live bar on/off, launch at login, vocabulary replacements, stats.

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

## Releasing (maintainer)
One-time: a **Developer ID Application** certificate in the login keychain and a notarytool profile
(`xcrun notarytool store-credentials whisperbar-notary --key AuthKey_….p8 --key-id … --issuer …`).
```bash
scripts/release.sh 0.2.0            # dry run: tests, build, sign, notarize app + DMG → dist/
scripts/release.sh 0.2.0 --publish  # from an up-to-date main: tag, GitHub Release, Homebrew tap PR
```

## License
MIT — see `LICENSE`. Third-party: mediaremote-adapter (BSD-3, vendored), FluidAudio (Apache-2.0), Parakeet v3 model (CC-BY-4.0).
