#!/usr/bin/env bash
# Build, sign with Developer ID, notarize and package WhisperBar as a DMG.
#
#   scripts/release.sh 0.1.0             build + notarize + DMG into dist/ (nothing is published)
#   scripts/release.sh 0.1.0 --publish   …then tag v0.1.0, create the GitHub Release with the DMG
#                                         and open a PR in the Homebrew tap with the new version
#
# Needs (one-time, see README → Releasing):
#   - "Developer ID Application" identity in the login keychain
#   - notarytool keychain profile (default: whisperbar-notary)
#   - gh CLI logged in
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version> [--publish]}"
PUBLISH="${2:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3" >&2; exit 1; }

SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
[[ -n "$SIGN_ID" ]] || { echo "no 'Developer ID Application' identity in the keychain" >&2; exit 1; }
NOTARY_PROFILE="${NOTARY_PROFILE:-whisperbar-notary}"
REPO="${REPO:-Artem-Babich/whisperbar}"
TAP_REPO="${TAP_REPO:-Artem-Babich/homebrew-tap}"
DIST=dist
APP=build/WhisperBar.app
DMG="$DIST/WhisperBar-$VERSION.dmg"

if [[ "$PUBLISH" == "--publish" ]]; then
  [[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean" >&2; exit 1; }
  [[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "publish from main" >&2; exit 1; }
  git fetch -q origin
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "main differs from origin/main" >&2; exit 1; }
  ! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || { echo "tag v$VERSION already exists" >&2; exit 1; }
elif [[ -n "$PUBLISH" ]]; then
  echo "unknown option: $PUBLISH" >&2; exit 1
fi

# notarytool exits 0 even when Apple rejects the upload, so check the final status explicitly.
notarize() {
  local out
  # Usually minutes; a new team's first submissions can take an hour or more.
  out=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --timeout "${NOTARY_TIMEOUT:-2h}" 2>&1) || true
  echo "$out" | grep -E "id:|status:" | tail -3
  if ! echo "$out" | grep -q "status: Accepted"; then
    local id; id=$(echo "$out" | awk '/^ *id:/{print $2; exit}')
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    echo "notarization failed for $1" >&2
    exit 1
  fi
}

echo "▶ tests"
swift test ${SWIFTPM_FLAGS:---disable-sandbox} 2>&1 | grep -E "Test run|error:" | tail -3

echo "▶ build $VERSION, signed with: $SIGN_ID"
VERSION="$VERSION" SIGN_ID="$SIGN_ID" scripts/build-app.sh | tail -1
rm -rf "$DIST" && mkdir -p "$DIST"

echo "▶ notarize the app (so it opens offline after being copied out of the DMG)"
ditto -c -k --keepParent "$APP" "$DIST/WhisperBar.zip"
notarize "$DIST/WhisperBar.zip"
xcrun stapler staple -q "$APP"
rm "$DIST/WhisperBar.zip"

echo "▶ DMG"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "WhisperBar $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
notarize "$DMG"
xcrun stapler staple -q "$DMG"

echo "▶ Gatekeeper check"
spctl --assess --type execute -vv "$APP" 2>&1 | head -2
spctl --assess --type open --context context:primary-signature -vv "$DMG" 2>&1 | head -2
SHA256=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
echo "✔ $DMG  sha256=$SHA256"

[[ "$PUBLISH" == "--publish" ]] || { echo "dry run: nothing published (add --publish)"; exit 0; }

echo "▶ GitHub Release v$VERSION"
git tag -a "v$VERSION" -m "WhisperBar $VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "WhisperBar $VERSION" --generate-notes

echo "▶ Homebrew tap PR"
TAP=$(mktemp -d)
gh repo clone "$TAP_REPO" "$TAP" -- -q
mkdir -p "$TAP/Casks"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA256/" resources/whisperbar.rb.template > "$TAP/Casks/whisperbar.rb"
git -C "$TAP" switch -q -c "whisperbar-$VERSION"
git -C "$TAP" add Casks/whisperbar.rb
git -C "$TAP" commit -q -m "whisperbar $VERSION"
git -C "$TAP" push -q origin "whisperbar-$VERSION"
gh pr create --repo "$TAP_REPO" --head "whisperbar-$VERSION" --title "whisperbar $VERSION" \
  --body "Release: https://github.com/$REPO/releases/tag/v$VERSION"
rm -rf "$TAP"
echo "✔ released v$VERSION — merge the tap PR to make 'brew install --cask' pick it up"
