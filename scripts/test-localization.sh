#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/AetherNotchQuota.app}"
OUTPUT="${NOTCHQUOTA_LOCALIZATION_OUTPUT:-$ROOT/build/localization-review}"
for LANGUAGE in zh-Hans en ja; do
  mkdir -p "$OUTPUT/$LANGUAGE"
  NOTCHQUOTA_LANGUAGE="$LANGUAGE" NOTCHQUOTA_SMOKE_DIR="$OUTPUT/$LANGUAGE" \
    "$APP/Contents/MacOS/NotchQuota" --localization-smoke > "$OUTPUT/$LANGUAGE/smoke.log" 2>&1
  tail -n 1 "$OUTPUT/$LANGUAGE/smoke.log"
done
printf 'Language screenshots: %s\n' "$OUTPUT"
