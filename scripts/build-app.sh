#!/bin/bash
set -euo pipefail

INSTALL_APP=false
BUILD_ARCH=native
while [ "$#" -gt 0 ]; do
  case "$1" in
    --install) INSTALL_APP=true; shift ;;
    --arch)
      [ "$#" -ge 2 ] || { echo '--arch needs native, arm64, x86_64, or universal' >&2; exit 2; }
      BUILD_ARCH="$2"; shift 2 ;;
    --help|-h)
      echo 'Usage: build-app.sh [--install] [--arch native|arm64|x86_64|universal]'
      echo 'Build into dist/. --install replaces /Applications/SnippetShelf.app and removes the dist app.'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$BUILD_ARCH" in native|arm64|x86_64|universal) ;; *) echo 'Unsupported architecture' >&2; exit 2 ;; esac

check_app_stopped() {
  local process_status
  if pgrep -x SnippetShelf >/dev/null; then
    printf 'Quit all running SnippetShelf copies before installing, then rerun with --install.\n' >&2
    return 1
  else
    process_status=$?
  fi
  if [ "$process_status" -ne 1 ]; then
    printf 'Could not check whether SnippetShelf is running. Installation stopped.\n' >&2
    return 1
  fi
  return 0
}

if [ "$INSTALL_APP" = true ] && ! check_app_stopped; then
  exit 1
fi

cd "$(dirname "$0")/.."
./scripts/release-metadata.sh --check
mkdir -p dist
APP_STAGE="$(mktemp -d "$PWD/dist/.app-stage.XXXXXX")"
trap 'rm -rf "$APP_STAGE"' EXIT
STAGED_APP="$APP_STAGE/SnippetShelf.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
if [ "$BUILD_ARCH" = universal ]; then
  swift build -c release --arch arm64
  ARM_BIN="$APP_STAGE/SnippetShelf-arm64"
  cp "$(swift build -c release --arch arm64 --show-bin-path)/SnippetShelf" "$ARM_BIN"
  lipo "$ARM_BIN" -verify_arch arm64
  swift build -c release --arch x86_64
  INTEL_BIN="$(swift build -c release --arch x86_64 --show-bin-path)/SnippetShelf"
  lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$STAGED_APP/Contents/MacOS/SnippetShelf"
else
  BUILD_OPTIONS=(-c release)
  if [ "$BUILD_ARCH" != native ]; then BUILD_OPTIONS=(-c release --arch "$BUILD_ARCH"); fi
  swift build "${BUILD_OPTIONS[@]}"
  BIN_DIR="$(swift build "${BUILD_OPTIONS[@]}" --show-bin-path)"
  cp "$BIN_DIR/SnippetShelf" "$STAGED_APP/Contents/MacOS/SnippetShelf"
fi
BINARY="$STAGED_APP/Contents/MacOS/SnippetShelf"
case "$BUILD_ARCH" in
  universal) lipo "$BINARY" -verify_arch arm64; lipo "$BINARY" -verify_arch x86_64 ;;
  native) lipo "$BINARY" -verify_arch "$(uname -m)" ;;
  *) lipo "$BINARY" -verify_arch "$BUILD_ARCH" ;;
esac
# Remove debug/linker source paths from distributed executables before signing.
xcrun strip -S "$BINARY"
if LC_ALL=C grep -aFq "$PWD/" "$BINARY"; then
  echo 'Local build paths remain in the executable. Refusing to package it.' >&2
  exit 1
fi
# Verify the actual executable, not only Info.plist's stated minimum OS.
xcrun vtool -show-build "$BINARY" | awk '
  $1 == "minos" { seen++; if ($2 != "13.0") bad=1 }
  END { if (!seen || bad) { print "Unexpected executable minimum macOS; expected 13.0" > "/dev/stderr"; exit 1 } }
'
cp Resources/Info.plist "$STAGED_APP/Contents/Info.plist"
cp LICENSE "$STAGED_APP/Contents/Resources/LICENSE"
./scripts/build-icon.sh "$STAGED_APP/Contents/Resources/SnippetShelf.icns"
codesign --force --sign - "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"
./scripts/release-metadata.sh --check "$STAGED_APP"
APP="dist/SnippetShelf.app"
if [ -L "$APP" ]; then echo 'Refusing to replace a symbolic link in dist/.' >&2; exit 1; fi
if [ -e "$APP" ]; then rm -rf "$APP"; fi
mv "$STAGED_APP" "$APP"
printf 'Built %s/dist/SnippetShelf.app (%s).\n' "$PWD" "$BUILD_ARCH"

if [ "$INSTALL_APP" = true ]; then
  DESTINATION="/Applications/SnippetShelf.app"
  # Refuse to replace a link or an unrelated item at the destination.
  if [ -L "$DESTINATION" ]; then
    printf 'The destination is a symbolic link. Install manually using Finder.\n' >&2
    exit 1
  fi
  if [ -e "$DESTINATION" ]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
    if [ "$EXISTING_ID" != 'org.snippetshelf.app' ]; then
      printf 'The destination is not a SnippetShelf app. Install manually using Finder.\n' >&2
      exit 1
    fi
  fi
  if ! INSTALL_STAGE="$(mktemp -d /Applications/.SnippetShelf-install.XXXXXX)"; then
    printf 'Cannot write to /Applications. Copy dist/SnippetShelf.app there using Finder instead.\n' >&2
    exit 1
  fi
  # Stage and verify the complete copy before touching the installed app.
  if ! ditto "$APP" "$INSTALL_STAGE/SnippetShelf.app" ||
     ! codesign --verify --strict "$INSTALL_STAGE/SnippetShelf.app"; then
    rm -rf "$INSTALL_STAGE"
    printf 'Installation failed while preparing the copy. The installed app was not changed.\n' >&2
    exit 1
  fi
  # Check again in case the app was opened during the build.
  if ! check_app_stopped; then
    rm -rf "$INSTALL_STAGE"
    exit 1
  fi
  if [ -e "$DESTINATION" ]; then
    if ! mv "$DESTINATION" "$INSTALL_STAGE/previous.app"; then
      rm -rf "$INSTALL_STAGE"
      printf 'Could not replace the installed app. Copy the build using Finder.\n' >&2
      exit 1
    fi
  fi
  if ! mv "$INSTALL_STAGE/SnippetShelf.app" "$DESTINATION"; then
    if [ -d "$INSTALL_STAGE/previous.app" ]; then
      if ! mv "$INSTALL_STAGE/previous.app" "$DESTINATION"; then
        printf 'Restore the previous app from %s/previous.app.\n' "$INSTALL_STAGE" >&2
        exit 1
      fi
    fi
    rm -rf "$INSTALL_STAGE"
    printf 'Installation failed. Any previous app has been restored.\n' >&2
    exit 1
  fi
  rm -rf "$INSTALL_STAGE"
  # Installation succeeded; keep only the installed copy for normal use.
  rm -rf "$APP"
  printf 'Installed %s\nRemoved the duplicate app from dist/.\nOpen it from Applications. Your saved snippets are preserved.\n' "$DESTINATION"
fi
