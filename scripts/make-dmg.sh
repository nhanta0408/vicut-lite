#!/usr/bin/env bash
# Packages dist/ViCut Lite.app into dist/ViCut-Lite-<version>.dmg with an /Applications shortcut.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.1.0}"
APP="$ROOT/dist/ViCut Lite.app"
DMG="$ROOT/dist/ViCut-Lite-$VERSION.dmg"

[[ -d "$APP" ]] || "$ROOT/scripts/build-app.sh"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname "ViCut Lite" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
du -h "$DMG"
echo "✓ $DMG"
