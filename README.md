<p align="center">
  <img src="Resources/AppIcon.svg" width="128" height="128" alt="ViCut Lite icon">
</p>

<h1 align="center">ViCut Lite</h1>

<p align="center">
  <b>Turn heavy screen recordings into GitHub-ready MP4s, and cut the boring parts on the way.</b><br>
  A tiny, free and open source macOS app.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-E4B53F" alt="License: GPL-3.0"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-0E0E0F?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-arm64-0E0E0F" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="https://github.com/nhanta0408/vicut-lite/pulls"><img src="https://img.shields.io/badge/PRs-welcome-E4B53F" alt="PRs welcome"></a>
</p>

---

A 2-minute screen recording from macOS is often 200 MB+, and GitHub only accepts 10 MB attachments on free plans.
ViCut Lite squeezes it under the limit in a few seconds, keeps text readable, and lets you cut or speed up the
parts nobody wants to watch (like waiting for an AI to think).

## Features

- **Drop to compress.** Drop videos on the window or the Dock icon. Output lands next to the original as
  `name-vicut.mp4`, ≤ 10 MB by default.
- **Hold ⌥ to edit first.** Opens the editor instead of compressing.
- **Cut & speed editor.** Mark spans as Cut, 2× or 4× on a zoomable timeline with snapping, edit exact times in the
  Spans panel, undo everything with ⌘Z.
- **Smart bitrate.** Picks the bitrate from your size target, steps resolution down only when text would get
  blurry, and re-encodes 2-pass if the first try overshoots.
- **Share fast.** Drag a finished row straight into a browser, Slack or Mail, or right-click → **Copy File**.
- **Fast or Light encoder.** Fast uses x264 on every core for the smallest files; Light uses Apple's media
  engine (VideoToolbox) and stays under one CPU core, so the Mac keeps cool while it works.
- **History.** Every export with its saving; reveal it in Finder later.
- **Tidy up.** Select finished rows and move their originals to the Trash.
- **Black & gold UI.** Native SwiftUI, one design system, dark by design.

## Install

1. Download the latest `.dmg` from [Releases](https://github.com/nhanta0408/vicut-lite/releases), or [build it yourself](#build-from-source).
2. Drag **ViCut Lite** into Applications.
3. The app is ad-hoc signed (not notarized), so open it the first time with right-click → **Open**, or run:

```bash
xattr -dr com.apple.quarantine "/Applications/ViCut Lite.app"
```

## Usage

| Do this | To get |
|---|---|
| Drop videos on the window | Compressed `name-vicut.mp4` next to each original |
| Hold **⌥** while dropping, or click **Edit** on a row | The editor |
| **Export…** in the editor (⌘E) | **Full quality** (`name-edited.mp4`, original size/fps) or **Compressed** (your Settings) |
| Sidebar → **History** / **Settings** | Past exports / target size, resolution, fps, encoder, audio, file suffix |

### Editor shortcuts

| Key | Action |
|---|---|
| Space | Play / pause |
| ← / → | Step 1 s |
| Drag on timeline | Select a range (edges snap within 1 s, hold ⌘ to place freely) |
| Click on timeline | Select the span under the pointer |
| I / O | Mark in / out at the playhead |
| C | Cut the selection / selected span |
| 2 / 4 / 8 | Speed up the selection / selected span |
| K | Back to Normal (clear cut or speed) |
| ⌘+ / ⌘− / ⌘0 | Zoom in / out / fit the whole clip |
| Z | Zoom to the selection or selected span |
| Pinch, ⌥-scroll | Zoom at the pointer |
| Scroll / swipe | Pan the zoomed timeline |
| ⌘Z | Undo |
| ⌘E | Export… |

With something selected, the timeline header also shows one-click **✂ / 2× / 4×** buttons and an eraser to clear the edit.
The **Spans** panel lists every cut and speed-up: click a row to jump to it, type new start / end times
(`m:ss.s`, Return to apply, Esc to discard), or pin it beside the video.

## How compression works

1. `ffprobe` reads duration, resolution and fps.
2. Video bitrate = `target × 0.95 / output duration − audio`. If that leaves too few bits per pixel for legible
   text, resolution steps down 1920 → 1280 → 960 → 640.
3. Encode with libx264 CRF 26 capped by `-maxrate`. If the file still overshoots, re-encode 2-pass at the exact bitrate.
4. Small H.264 files already under the target are just remuxed (`-c copy`).
5. With the **Light** encoder, decode and encode run on VideoToolbox (`-hwaccel videotoolbox`, `h264_videotoolbox -q:v`);
   if the file overshoots, it re-encodes once at the planned bitrate (VideoToolbox has no 2-pass).

Cuts and speed-ups are one `filter_complex` (`trim` / `setpts` / `atempo` → `concat` → `scale,fps`), so there is a
single encode.

## Build from source

Requires Xcode 16+ (Swift 6), macOS 14+ and Apple Silicon.

```bash
git clone https://github.com/nhanta0408/vicut-lite.git && cd vicut-lite
swift test                     # unit + integration tests
./scripts/build-app.sh         # → dist/ViCut Lite.app (downloads a pinned static ffmpeg 9.0.2 into vendor/bin)
./scripts/make-dmg.sh          # → dist/ViCut-Lite-0.1.0.dmg
swift run VicutLite            # run unbundled (ffmpeg from vendor/bin, Homebrew or $VICUT_FFMPEG_DIR)
```

| Path | What lives there |
|---|---|
| `Sources/VicutCore` | Pure logic: probing, bitrate planning, ffmpeg command building, timeline math, history (fully tested) |
| `Sources/VicutLite` | SwiftUI app: views, view models, `DesignSystem/` tokens and components |
| `Tests/VicutCoreTests` | Swift Testing suites, including real ffmpeg integration tests |
| `scripts/` | App bundle, DMG, icon and ffmpeg fetch scripts |

## Contributing

Issues and pull requests are welcome.

- Branch from `develop`; `main` is the release branch.
- Keep `swift build` warning-free and `swift test` green.
- UI uses the tokens in `Sources/VicutLite/DesignSystem/DesignTokens.swift`: no raw colors, sizes or fonts in views.
- Commit messages are one short line.

## License

ViCut Lite is free software, licensed under the **[GNU General Public License v3.0](LICENSE)**. You may use, study,
share and modify it; if you distribute a modified version, it must stay under the GPL with its source available.

Release builds bundle unmodified **[FFmpeg](https://ffmpeg.org) 9.0.2** (with x264), which is also GPLv3. Its
source, build configuration and a written source offer are in **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.
In the app, click the credit at the bottom of the sidebar (or **ViCut Lite → About**) to see the license.

<p align="center"><sub>Made by Nhan Ta (Brian) · black &amp; gold since 2026</sub></p>
