#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ] || [ "$1" = --help ]; then
  echo 'Usage: build-dmg.sh APP_PATH OUTPUT.dmg' >&2
  echo 'Creates a drag-to-Applications image. It does not sign, notarize, or publish.' >&2
  exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$1"
OUTPUT="$2"
[ ! -e "$OUTPUT" ] && [ ! -L "$OUTPUT" ] || { echo 'Output already exists; refusing to overwrite.' >&2; exit 1; }
[ -d "$APP" ] && [ ! -L "$APP" ] || { echo 'Expected an app directory, not a symbolic link.' >&2; exit 1; }
ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
[ "$ID" = org.snippetshelf.app ] || { echo 'Unexpected app identity.' >&2; exit 1; }
"$ROOT/scripts/release-metadata.sh" --check "$APP"
codesign --verify --strict "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :SnippetShelfReleaseVersion' "$APP/Contents/Info.plist")"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/SnippetShelf-dmg.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/payload"
ditto "$APP" "$WORK/payload/SnippetShelf.app"
ln -s /Applications "$WORK/payload/Applications"
# Stage only the app and installation link, never dist/, the repo, or local data.
hdiutil create -volname "SnippetShelf $VERSION" -srcfolder "$WORK/payload" -format UDZO -ov "$WORK/image.dmg" >/dev/null
hdiutil verify "$WORK/image.dmg" >/dev/null
mkdir -p "$(dirname "$OUTPUT")"
# noclobber prevents replacing an output created while the image was building.
(set -o noclobber; cat "$WORK/image.dmg" > "$OUTPUT")
echo "Created $OUTPUT. Public distribution additionally requires Developer ID signing and notarization."
