#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL_DIR="$ROOT/.build/release-tools"
mkdir -p "$TOOL_DIR"
# Compile into a unique file, then replace the cache atomically.
if [ ! -x "$TOOL_DIR/metadata" ] || [ "$ROOT/Sources/SnippetCore/ReleaseVersion.swift" -nt "$TOOL_DIR/metadata" ] || [ "$ROOT/scripts/ReleaseMetadata/main.swift" -nt "$TOOL_DIR/metadata" ]; then
  TOOL_WORK="$(mktemp -d "$TOOL_DIR/compile.XXXXXX")"
  trap 'rm -rf "$TOOL_WORK"' EXIT
  swiftc -module-cache-path "$TOOL_DIR/module-cache" "$ROOT/Sources/SnippetCore/ReleaseVersion.swift" "$ROOT/scripts/ReleaseMetadata/main.swift" -o "$TOOL_WORK/metadata"
  mv "$TOOL_WORK/metadata" "$TOOL_DIR/metadata"
  rm -rf "$TOOL_WORK"
  trap - EXIT
fi
exec "$TOOL_DIR/metadata" "$ROOT" "$@"
