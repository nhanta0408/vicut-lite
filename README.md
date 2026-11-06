<p align="center">
  <img src="Resources/AppIcon.svg" width="128" height="128" alt="ViCut Lite icon">
</p>

<h1 align="center">ViCut Lite</h1>

<p align="center">
  <b>Turn heavy screen recordings into GitHub-ready MP4s, and cut the boring parts on the way.</b><br>
  A tiny, free and open source macOS app.
</p>

<p align="center">
  <a href="https://github.com/nhanta0408/vicut-lite/releases/latest"><img src="https://img.shields.io/github/v/release/nhanta0408/vicut-lite?color=E4B53F&label=download" alt="Download latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-E4B53F" alt="License: GPL-3.0"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-0E0E0F?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-arm64-0E0E0F" alt="Apple Silicon">
</p>

## Install

1. Download **`ViCut-Lite-x.y.z.dmg`** from the [latest release](https://github.com/nhanta0408/vicut-lite/releases/latest).
2. Open it and drag **ViCut Lite** into **Applications**.
3. Open **ViCut Lite**. The first time, macOS asks you to confirm an app from outside the App Store:
   it takes one click, see [First launch on macOS](#first-launch-on-macos).

Requires macOS 14+ on Apple Silicon.

## Why

A 2-minute screen recording is often 200 MB+, and GitHub only takes 10 MB attachments on free plans.
ViCut Lite squeezes it under the limit in seconds, keeps text readable, and lets you cut or speed up the parts
nobody wants to watch.

<table>
  <tr><th>Quick Compress</th></tr>
  <tr><td align="center"><img src="docs/screenshots/home-queue.png" alt="Queue: three screen recordings compressed by 95–99%, each with Edit, Show in Finder and Delete"></td></tr>
</table>

<table>
  <tr><th>Simple Edit with Cut, Speed-up</th></tr>
  <tr><td align="center"><img src="docs/screenshots/editor.png" alt="Editor: timeline with a cut span, a 2× span and an 8× span, plus one-click Cut, 2× and 4× buttons"></td></tr>
</table>

### Also in the box

<table>
  <tr>
    <th width="25%">Drop zone while dragging</th>
    <th width="25%">Working progress card</th>
    <th width="25%">Live in the menu bar</th>
    <th width="25%">One drop zone</th>
  </tr>
  <tr>
    <td align="center" valign="top"><img src="docs/screenshots/drop-zone.png" width="200" alt="Floating drop zone in the screen corner while dragging a video: Release to compress"></td>
    <td align="center" valign="top"><img src="docs/screenshots/progress-card.png" width="200" alt="Progress card after a drop: Compressing 1 video with a progress bar"></td>
    <td align="center" valign="top"><img src="docs/screenshots/menu-bar.png" width="200" alt="Menu bar popover: drop target, recent jobs, Open ViCut Lite, Settings and Quit"></td>
    <td align="center" valign="top"><img src="docs/screenshots/home-empty.png" width="200" alt="Empty Home: one large drop zone, hold Option to open the editor instead"></td>
  </tr>
</table>

## Quick start

| Do this | You get |
|---|---|
| Drop videos on the window | `name-vicut.mp4` next to each original, ≤ 10 MB |
| Hold <kbd>⌥</kbd> while dropping, or click **Edit** | The editor: mark parts as **Cut**, **2×** or **4×**, then **Export** (⌘E) |
| Drag a finished row into GitHub, Slack or Mail | The compressed file, attached |
| Start dragging a video anywhere, or drop it on the menu bar icon | A drop zone pops up in the screen corner: drop to compress (<kbd>⌥</kbd> to edit). Hide the Dock icon in **Settings → Menu bar** |
| Sidebar → **Settings** | Target size, **Smaller / Balanced / Sharper** quality, resolution, fps, audio, **Fast / Light** encoder |

Editor keys: <kbd>Space</kbd> play · drag to select · <kbd>C</kbd> cut · <kbd>2</kbd> / <kbd>4</kbd> speed up ·
<kbd>K</kbd> back to normal · <kbd>⌘Z</kbd> undo · <kbd>⌘E</kbd> export.

## Build from source

```bash
git clone https://github.com/nhanta0408/vicut-lite.git && cd vicut-lite
./scripts/build-app.sh   # → dist/ViCut Lite.app  (Xcode 16+, macOS 14+, Apple Silicon)
```

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Free software under the [GNU GPL v3](LICENSE). Release builds bundle unmodified [FFmpeg](https://ffmpeg.org) 9.0.2
(GPLv3); source and notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## FAQ

### First launch on macOS

ViCut Lite is free and open source, but it isn't notarized by Apple yet (that needs a paid Apple Developer
account). So the first time you open it, macOS shows this:

<p align="center">
  <img src="docs/screenshots/gatekeeper-not-opened.png" width="254" alt="macOS dialog: “ViCut Lite” Not Opened. Apple could not verify “ViCut Lite” is free of malware. Buttons: Move to Trash, Done">
</p>

Click **Done** (not *Move to Trash*), then allow it once in either way:

- **System Settings:** go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**
  next to the ViCut Lite message. On macOS 14 you can also right-click the app → **Open** → **Open**.
- **Terminal:**

  ```bash
  xattr -dr com.apple.quarantine "/Applications/ViCut Lite.app"
  ```

After that it opens normally. You can check what you're running: the whole source is in this repo, and each
release lists the SHA-256 of its `.dmg`.

<p align="center"><sub>Made by Nhan Ta (Brian)</sub></p>
