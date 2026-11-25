#!/usr/bin/env bash
# Build WhisperBar.app into ./build.
#   scripts/build-app.sh            build + sign
#   SIGN_ID="-" scripts/build-app.sh  ad-hoc signing (permissions reset on every rebuild)
set -euo pipefail
cd "$(dirname "$0")/.."

# A stable identity keeps Microphone/Accessibility grants across rebuilds.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')}"
SIGN_ID="${SIGN_ID:--}"

# --disable-sandbox: SwiftPM's own sandbox can't nest inside an already sandboxed shell.
swift build -c release --product WhisperBar ${SWIFTPM_FLAGS:---disable-sandbox}

APP=build/WhisperBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WhisperBar "$APP/Contents/MacOS/WhisperBar"
cp resources/Info.plist "$APP/Contents/Info.plist"

# Media pause/resume helper (vendor/mediaremote-adapter, BSD-3): framework + perl script.
cmake -S vendor/mediaremote-adapter -B .build/mediaremote-adapter -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build .build/mediaremote-adapter --target MediaRemoteAdapter >/dev/null
MR="$APP/Contents/Resources/MediaRemote"
mkdir -p "$MR"
cp -R .build/mediaremote-adapter/MediaRemoteAdapter.framework "$MR/"
cp vendor/mediaremote-adapter/bin/mediaremote-adapter.pl "$MR/"
codesign --force --sign "$SIGN_ID" "$MR/MediaRemoteAdapter.framework"

codesign --force --options runtime --entitlements resources/WhisperBar.entitlements \
  --sign "$SIGN_ID" "$APP"
codesign --verify --verbose=1 "$APP"
echo "built $APP (signed with: $SIGN_ID)"
