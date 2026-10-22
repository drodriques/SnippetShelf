#!/bin/bash
# Offline input/overwrite guards; no signing identities or network requests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/SnippetShelf-packaging-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/Fixture.app"
mkdir -p "$APP/Contents"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
"$ROOT/scripts/release-metadata.sh" --check "$APP" >/dev/null
/usr/libexec/PlistBuddy -c 'Set :SnippetShelfReleaseVersion 9.9.9' "$APP/Contents/Info.plist"
if "$ROOT/scripts/release-metadata.sh" --check "$APP" > "$WORK/result" 2>&1; then exit 1; fi
grep -q 'Version mismatch' "$WORK/result"
printf 'do not replace' > "$WORK/existing.dmg"
if "$ROOT/scripts/build-dmg.sh" "$APP" "$WORK/existing.dmg" > "$WORK/result" 2>&1; then exit 1; fi
[ "$(cat "$WORK/existing.dmg")" = 'do not replace' ]
grep -q 'refusing to overwrite' "$WORK/result"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier org.unrelated.app' "$APP/Contents/Info.plist"
if "$ROOT/scripts/build-dmg.sh" "$APP" "$WORK/invalid.dmg" > "$WORK/result" 2>&1; then exit 1; fi
grep -q 'Unexpected app identity' "$WORK/result"
ln -s "$APP" "$WORK/linked.app"
if "$ROOT/scripts/build-dmg.sh" "$WORK/linked.app" "$WORK/linked.dmg" > "$WORK/result" 2>&1; then exit 1; fi
grep -q 'not a symbolic link' "$WORK/result"
[ ! -e "$WORK/invalid.dmg" ] && [ ! -e "$WORK/linked.dmg" ]
echo '4 offline packaging guard checks passed.'
