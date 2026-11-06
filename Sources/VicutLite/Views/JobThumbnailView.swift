import AVFoundation
import SwiftUI

/// First frame + clip length for a queue row. AVFoundation can't read every container
/// (e.g. .mkv/.webm), so both fields are optional and the view falls back to a placeholder.
struct VideoPreview: Sendable {
  let image: CGImage?
  let duration: Double?

  static let empty = VideoPreview(image: nil, duration: nil)

  /// Grab a frame a little into the clip: screen recordings often start on a blank frame.
  static let frameOffset = 1.0
  /// Rendered at 2× the thumbnail for Retina.
  static let pixelScale: CGFloat = 2
  /// Standard video timescale (divisible by common frame rates).
  static let timescale: CMTimeScale = 600

  static func load(_ url: URL) async -> VideoPreview {
    let asset = AVURLAsset(url: url)
    let duration = try? await asset.load(.duration).seconds
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let side = DS.Size.thumbnail * pixelScale
    generator.maximumSize = CGSize(width: side, height: side)
    let seconds = min(frameOffset, (duration ?? 0) / 2)
    let image = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: timescale)).image
    return VideoPreview(image: image, duration: duration)
  }
}

struct JobThumbnailView: View {
  let url: URL
  /// 0…1 while encoding; shows the % overlay.
  let progress: Double?
  @State private var preview = VideoPreview.empty

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
    ZStack {
      shape.fill(DS.Color.bgThumb)
      if let image = preview.image {
        Image(decorative: image, scale: VideoPreview.pixelScale)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        DSIcon("film", size: DS.Size.glyphLarge)
          .foregroundStyle(DS.Color.textFaint)
      }
      if let progress {
        DS.Color.bgThumbOverlay
        Text("\(Int(progress * 100))%")
          .dsText(DS.Typography.heading)
          .foregroundStyle(DS.Color.gold300)
          .monospacedDigit()
      }
    }
    .overlay(alignment: .bottomTrailing) {
      if let duration = preview.duration.flatMap(QueueFormat.clipDuration) {
        Text(duration)
          .dsText(DS.Typography.tiny)
          .foregroundStyle(DS.Color.textPrimary)
          .padding(.horizontal, DS.Space.s1)
          .padding(.vertical, DS.Space.s0_5 / 2)
          .background(RoundedRectangle(cornerRadius: DS.Radius.xs).fill(DS.Color.bgThumbChip))
          .padding(DS.Space.s1)
      }
    }
    .frame(width: DS.Size.thumbnail, height: DS.Size.thumbnail)
    .clipShape(shape)
    .overlay(shape.strokeBorder(DS.Color.borderThumb, lineWidth: DS.Stroke.hairline))
    .task(id: url) {
      preview = await VideoPreview.load(url)
    }
  }
}
