#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/AetherNotchQuota.app}"
VERSION="$(tr -d '\n' < "$ROOT/VERSION")"
file "$APP/Contents/MacOS/NotchQuota" | grep -q arm64
codesign --verify --deep --strict "$APP"
ACTUAL="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ "$ACTUAL" = "$VERSION" ]
[ -f "$APP/Contents/Resources/AppIcon.icns" ]
cmp "$ROOT/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
[ -d "$APP/Contents/Resources/NotchQuota_NotchQuota.bundle" ]
[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]
RESOURCE_ROOT="$APP/Contents/Resources/NotchQuota_NotchQuota.bundle"
if [ -d "$RESOURCE_ROOT/Contents/Resources" ]; then RESOURCE_ROOT="$RESOURCE_ROOT/Contents/Resources"; fi
for LANGUAGE in zh-Hans en ja; do
  [ -f "$RESOURCE_ROOT/$LANGUAGE.lproj/Localizable.strings" ]
done
for CHARACTER in panda bunny fox turtle ghost cloud bear cat penguin; do
  [ -f "$RESOURCE_ROOT/storybook-$CHARACTER.png" ]
done
[ -f "$RESOURCE_ROOT/soft-panda-drink.png" ]
[ -f "$RESOURCE_ROOT/soft-panda-music.png" ]
for SCENE in walk home read drink swim; do
  [ -f "$RESOURCE_ROOT/turtle-$SCENE.png" ]
done
[ -f "$APP/Contents/Resources/Sparkle-LICENSE" ]
/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP/Contents/Info.plist" >/dev/null
printf 'Release layout verified: %s arm64\n' "$VERSION"
