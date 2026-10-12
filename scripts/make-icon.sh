#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Packaging/AppIcon-1024.png"
OUTPUT="${1:-$ROOT/Packaging/AppIcon.icns}"
[ -f "$SOURCE" ]
ICON_WORK="$(mktemp -d "${TMPDIR:-/tmp}/aethernq-icon.XXXXXX")"
trap 'rm -rf "$ICON_WORK"' EXIT
ICONSET="$ICON_WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
# Native macOS representations, including Retina. Preserve the source alpha.
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$OUTPUT"
printf 'Generated %s from AppIcon-1024.png\n' "$OUTPUT"
