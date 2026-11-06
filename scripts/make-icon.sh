#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from the SVG master Resources/AppIcon.svg.
# Uses only stock macOS tools: swift (AppKit SVG rendering) + iconutil.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/Resources/AppIcon.svg"
ICNS="$ROOT/Resources/AppIcon.icns"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "▸ rendering master"
swift "$ROOT/scripts/render-svg.swift" "$SVG" "$WORK/master.png" 1024

for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale))
    name="icon_${size}x${size}"
    [[ $scale == 2 ]] && name="${name}@2x"
    if [[ $px == 1024 ]]; then
      cp "$WORK/master.png" "$ICONSET/$name.png"
    else
      swift "$ROOT/scripts/render-svg.swift" "$SVG" "$ICONSET/$name.png" "$px"
    fi
  done
done

echo "▸ iconutil"
iconutil -c icns "$ICONSET" -o "$ICNS"
echo "✓ wrote $ICNS"
