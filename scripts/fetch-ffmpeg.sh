#!/usr/bin/env bash
# Downloads pinned static arm64 ffmpeg/ffprobe builds (martin-riedl.de, GPL, includes libx264)
# into vendor/bin and verifies their checksums. Re-running is a no-op when they're present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/bin"
BASE_URL="https://ffmpeg.martin-riedl.de/download/macos/arm64/1789931890_9.0.2"
# macOS ships bash 3.2 (no associative arrays).
expected_sha256() {
  case "$1" in
    ffmpeg) echo "c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924" ;;
    ffprobe) echo "fcbe839537485eaee7a7a8bc5cbc0f90d53617e80943e8a5b2e31cb851197ea6" ;;
  esac
}

mkdir -p "$DEST"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for tool in ffmpeg ffprobe; do
  if [[ -x "$DEST/$tool" ]]; then
    echo "✓ $tool already in vendor/bin"
    continue
  fi
  echo "↓ $tool 9.0.2 (static arm64)"
  curl --fail --location --silent --show-error -o "$WORK/$tool.zip" "$BASE_URL/$tool.zip"
  actual="$(shasum -a 256 "$WORK/$tool.zip" | awk '{print $1}')"
  if [[ "$actual" != "$(expected_sha256 "$tool")" ]]; then
    echo "✗ checksum mismatch for $tool.zip: $actual" >&2
    exit 1
  fi
  mkdir -p "$WORK/$tool"
  unzip -q -o "$WORK/$tool.zip" -d "$WORK/$tool"
  install -m 0755 "$WORK/$tool/$tool" "$DEST/$tool"
  xattr -c "$DEST/$tool" 2>/dev/null || true
done

"$DEST/ffmpeg" -hide_banner -encoders 2>/dev/null | grep -q libx264 || { echo "✗ bundled ffmpeg lacks libx264" >&2; exit 1; }
echo "ffmpeg ready in $DEST"
