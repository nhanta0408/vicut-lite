# ViCut Lite

Tiny macOS app that turns heavy screen recordings into GitHub-ready `.mp4` files (≤ 10 MB by default),
with a simple editor to cut or speed up (2×/4×/8×) the boring parts — e.g. waiting for an AI to think.

## Use

Drop videos anywhere in the window (or on the Dock icon) to compress them. Output lands next to the original as
`name-vicut.mp4`. Drag a finished row into the browser, or right-click → **Copy File** and paste into a GitHub comment.

- **Hold ⌥ while dropping** (or use **Edit first** / **Edit** on a row) to open the editor instead. When done,
  **Export…** offers **Full quality** (original resolution/fps, no size limit, `name-edited.mp4`) or **Compressed**
  (your Settings, `name-vicut.mp4`).
- **Select** lets you pick finished rows and move their originals to the Trash, keeping the compressed files.

| Key | Action |
|---|---|
| Space | Play / pause |
| ← / → | Step 1 s |
| drag on timeline | Select a range — edges snap to marks and clip ends within 1 s (hold ⌘ to place freely) |
| click on timeline | Select the span under the pointer (C / 2 / 4 / 8 / K then retype it) |
| ⌘+ / ⌘− / ⌘0 | Zoom timeline in / out / fit whole clip |
| Z | Zoom to the selection or selected span |
| pinch, ⌥-scroll | Zoom at the pointer |
| scroll / swipe | Pan the zoomed timeline (or drag the overview bar below it) |
| I / O | Mark in / out at the playhead |
| C | Cut selection / selected span |
| 2 / 4 / 8 | Speed up selection / selected span |
| K | Keep (clear cut/speed on selection / selected span) |
| ⌘Z | Undo |
| ⌘E | Export… (choose full quality or compressed) |

**Spans** (timeline header) lists every part: click a row to select and jump to it, type new start / end times
(`m:ss.s`, Return to apply, Esc to discard), or change its type with the pencil. Pin it to dock it beside the video.
Single-key shortcuts are paused while a time field is being edited.

Settings (⌘,) apply to compression: target size (5/10/25 MB/no limit), max resolution, fps, audio, mute sped-up parts, file suffix.

## How compression works

1. `ffprobe` reads duration/resolution/fps.
2. Video bitrate = `target × 0.95 / output duration − audio`. If that's too few bits per pixel for legible
   text, resolution steps down 1920 → 1280 → 960 → 640.
3. Encode with libx264 CRF 26 capped by `-maxrate`; if the file still overshoots, re-encode 2-pass at the exact bitrate.
4. Small h264 files already under the target are just remuxed (`-c copy`).

Cuts/speed-ups are one `filter_complex` (`trim`/`setpts`/`atempo` → `concat` → `scale,fps`), so there's a single encode.

## Build

Requires Xcode 16+ (Swift 6), macOS 14+, Apple Silicon.

```bash
swift test                     # unit + integration tests (uses ffmpeg from vendor/bin, Homebrew, or $VICUT_FFMPEG_DIR)
./scripts/build-app.sh         # → dist/ViCut Lite.app (downloads pinned static ffmpeg 9.0.2 into vendor/bin)
./scripts/make-dmg.sh          # → dist/ViCut-Lite-0.1.0.dmg
swift run VicutLite            # run without bundling (needs ffmpeg on Homebrew or $VICUT_FFMPEG_DIR)
```

## Install

Open the `.dmg`, drag **ViCut Lite** into Applications. The app is ad-hoc signed (not notarized), so the first
launch needs right-click → **Open**, or:

```bash
xattr -dr com.apple.quarantine "/Applications/ViCut Lite.app"
```

## License note

The bundled ffmpeg build (martin-riedl.de) includes libx264 and is GPL-licensed, so distributed builds of this
app must comply with the GPL.
