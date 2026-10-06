#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s OUTPUT.icns\n' "$0" >&2
  exit 2
fi
SOURCE="$(cd "$(dirname "$0")/.." && pwd)/Assets/AppIcon/SnippetShelf-original.png"
ICON_WORK="$(mktemp -d "${TMPDIR:-/tmp}/SnippetShelf-icon.XXXXXX")"
trap 'rm -rf "$ICON_WORK"' EXIT
ICONSET="$ICON_WORK/SnippetShelf.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$1"
