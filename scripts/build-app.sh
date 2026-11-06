#!/usr/bin/env bash
# Builds "dist/ViCut Lite.app": release binary + bundled static ffmpeg, ad-hoc signed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.1.0}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
APP="$ROOT/dist/ViCut Lite.app"

cd "$ROOT"
"$ROOT/scripts/fetch-ffmpeg.sh"

echo "▸ swift build (release, arm64)"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/VicutLite"

echo "▸ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
install -m 0755 "$BIN" "$APP/Contents/MacOS/VicutLite"
install -m 0755 vendor/bin/ffmpeg vendor/bin/ffprobe "$APP/Contents/Resources/bin/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
# GPL: the license, the third-party notices and the About-panel credits travel with every build.
install -m 0644 LICENSE THIRD_PARTY_NOTICES.md Resources/Credits.html "$APP/Contents/Resources/"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/"
fi

echo "▸ ad-hoc codesign"
codesign --force --sign - "$APP/Contents/Resources/bin/ffmpeg" "$APP/Contents/Resources/bin/ffprobe"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

du -sh "$APP"
echo "✓ built $APP"
