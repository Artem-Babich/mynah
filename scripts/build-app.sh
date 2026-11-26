#!/usr/bin/env bash
# Build Mynah.app into ./build.
#   scripts/build-app.sh            build + sign
#   SIGN_ID="-" scripts/build-app.sh  ad-hoc signing (permissions reset on every rebuild)
#   VERSION=0.2.0 SIGN_ID="Developer ID Application: …" scripts/build-app.sh   release build (see release.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

# A stable identity keeps Microphone/Accessibility grants across rebuilds.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')}"
SIGN_ID="${SIGN_ID:--}"

# --disable-sandbox: SwiftPM's own sandbox can't nest inside an already sandboxed shell.
swift build -c release --product Mynah ${SWIFTPM_FLAGS:---disable-sandbox}

APP=build/Mynah.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Mynah "$APP/Contents/MacOS/Mynah"
cp resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "${BUILD_NUMBER:-$VERSION}" "$APP/Contents/Info.plist"
fi

# Notarization needs a secure timestamp; local dev builds skip the network round-trip.
if [[ "$SIGN_ID" == Developer\ ID* ]]; then TIMESTAMP=--timestamp; else TIMESTAMP=--timestamp=none; fi

# Media pause/resume helper (vendor/mediaremote-adapter, BSD-3): framework + perl script.
cmake -S vendor/mediaremote-adapter -B .build/mediaremote-adapter -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build .build/mediaremote-adapter --target MediaRemoteAdapter >/dev/null
MR="$APP/Contents/Resources/MediaRemote"
mkdir -p "$MR"
cp -R .build/mediaremote-adapter/MediaRemoteAdapter.framework "$MR/"
cp vendor/mediaremote-adapter/bin/mediaremote-adapter.pl "$MR/"
codesign --force --options runtime $TIMESTAMP --sign "$SIGN_ID" "$MR/MediaRemoteAdapter.framework"

codesign --force --options runtime $TIMESTAMP --entitlements resources/Mynah.entitlements \
  --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=1 "$APP"
echo "built $APP (signed with: $SIGN_ID)"
