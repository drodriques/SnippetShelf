#!/bin/bash
set -euo pipefail

INSTALL_APP=false
case "${1:-}" in
  "") ;;
  --install) INSTALL_APP=true ;;
  --help|-h)
    printf 'Usage: %s [--install]\n\nBuild SnippetShelf into dist/.\n--install installs or replaces /Applications/SnippetShelf.app, then removes the dist app.\nQuit running SnippetShelf copies before installing.\n' "$0"
    exit 0
    ;;
  *) printf 'Unknown option: %s\nUse --help for usage.\n' "$1" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'Expected at most one option. Use --help for usage.\n' >&2
  exit 2
fi

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
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="dist/SnippetShelf.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SnippetShelf" "$APP/Contents/MacOS/SnippetShelf"
cp Resources/Info.plist "$APP/Contents/Info.plist"
./scripts/build-icon.sh "$APP/Contents/Resources/SnippetShelf.icns"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'Built %s/dist/SnippetShelf.app\n' "$PWD"

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
