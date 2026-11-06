# Third-party notices

ViCut Lite is licensed under the [GNU General Public License v3.0](LICENSE). Release builds (`dist/ViCut Lite.app`
and the `.dmg`) also ship the third-party programs listed below, unmodified, as separate executables in
`ViCut Lite.app/Contents/Resources/bin/`. ViCut Lite runs them as child processes; it does not link them.

## FFmpeg 9.0.2 (`ffmpeg`, `ffprobe`)

- **License:** GNU General Public License v3.0 or later. The build enables `--enable-gpl` and `--enable-version3`,
  and includes GPL components such as libx264 and libx265, so the binaries as a whole are GPLv3.
- **Copyright:** © 2000–2026 the FFmpeg developers. <https://ffmpeg.org>
- **Binary source:** static macOS arm64 build by Martin Riedl, <https://ffmpeg.martin-riedl.de>
  (pinned in [`scripts/fetch-ffmpeg.sh`](scripts/fetch-ffmpeg.sh)).
- **Corresponding source:**
  - FFmpeg 9.0.2 source: <https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz>
  - Build script used to produce the binaries: <https://git.martin-riedl.de/ffmpeg/build-script>
  - Configuration of the bundled binaries (from `ffmpeg -version`):

    ```
    --prefix=/Volumes/ffmpeg_arm64/out --pkg-config-flags=--static --extra-version='https://www.martin-riedl.de'
    --enable-gray --enable-libxml2 --enable-version3 --enable-gpl --enable-openssl --enable-libfreetype
    --enable-fontconfig --enable-libharfbuzz --enable-libbluray --enable-libsnappy --enable-libsrt --enable-libvmaf
    --enable-libass --enable-libklvanc --enable-libzimg --enable-libzvbi --enable-libaom --enable-libdav1d
    --enable-libopenh264 --enable-libopenjpeg --enable-librav1e --enable-libsvtav1 --enable-libvpx --enable-libvvenc
    --enable-libwebp --enable-libx264 --enable-libx265 --enable-libmp3lame --enable-libopus --enable-libvorbis
    --enable-libtheora
    ```

- **Written offer:** for at least three years after we distribute a given release, anyone may request the complete
  corresponding source of the bundled FFmpeg binaries by opening an issue at
  <https://github.com/nhanta0408/vicut-lite/issues>. We will provide it at no charge beyond the cost of distribution.

### Libraries statically linked into the FFmpeg binaries

| Library | Used by ViCut Lite | License |
|---|---|---|
| x264 | H.264 encode (Fast encoder) | GPL-2.0-or-later |
| x265, aom, rav1e, SVT-AV1, VVenC, vpx, dav1d, openh264, OpenJPEG, libwebp, theora, vorbis, opus, LAME | Not used, present in the build | GPL / LGPL / BSD-style, see each project |
| libass, freetype, harfbuzz, fontconfig, libxml2, zimg, zvbi, libbluray, snappy, srt, vmaf, klvanc, OpenSSL | Not used, present in the build | LGPL / MIT / BSD / Apache-2.0, see each project |

The FFmpeg project's license overview: <https://ffmpeg.org/legal.html>.

## Patent note

H.264 and AAC are covered by patent pools in some countries. ViCut Lite is free software distributed at no charge;
whether you need a patent license to use or redistribute it depends on where and how you do so. The **Light**
encoder setting uses Apple's built-in VideoToolbox encoder instead of x264.

## Apple frameworks

SwiftUI, AppKit, AVFoundation and VideoToolbox are part of macOS and are used under Apple's macOS license.
