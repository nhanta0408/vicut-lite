import Foundation

public struct EncodePlan: Sendable, Equatable {
  public enum Mode: Sendable, Equatable {
    case remux
    case encode
  }

  public var mode: Mode
  public var width: Int
  public var height: Int
  public var fps: Int
  /// nil = quality-only encode (no size target).
  public var videoKbps: Int?
  /// 0 = no audio track in the output.
  public var audioKbps: Int
  /// nil = keep source channel layout.
  public var audioChannels: Int?
  public var crf: Int

  /// Visually clean for screen content while still small; maxrate keeps it under the size budget.
  public static let defaultCrf = 26

  public init(
    mode: Mode, width: Int, height: Int, fps: Int, videoKbps: Int?, audioKbps: Int, audioChannels: Int?,
    crf: Int = defaultCrf
  ) {
    self.mode = mode
    self.width = width
    self.height = height
    self.fps = fps
    self.videoKbps = videoKbps
    self.audioKbps = audioKbps
    self.audioChannels = audioChannels
    self.crf = crf
  }
}

public enum BitratePlanner {
  /// Container overhead headroom so the muxed file lands under the target.
  static let sizeHeadroom = 0.95
  /// Below this bits-per-pixel, h264 turns screen text to mush; trade resolution for clarity instead.
  static let minBitsPerPixel = 0.02
  static let resolutionLadder = [1920, 1280, 960, 640]
  static let minVideoKbps = 100
  static let monoAudioKbps = 64
  static let stereoAudioKbps = 128

  public static func plan(
    source: MediaInfo,
    outputDuration: Double,
    settings: CompressSettings,
    edited: Bool
  ) -> EncodePlan {
    let fps = max(1, min(Int(source.fps.rounded()), settings.fpsCap))
    let crf = settings.crf ?? EncodePlan.defaultCrf
    let (audioKbps, audioChannels) = audioBudget(source: source, mode: settings.audio)
    var (width, height) = scaled(source: source, longestSide: settings.maxDimension)

    if shouldRemux(source: source, settings: settings, edited: edited, fps: fps, width: width) {
      return EncodePlan(
        mode: .remux, width: source.width, height: source.height, fps: fps,
        videoKbps: nil, audioKbps: audioKbps, audioChannels: audioChannels, crf: crf
      )
    }

    guard let target = settings.targetBytes, outputDuration > 0 else {
      return EncodePlan(
        mode: .encode, width: width, height: height, fps: fps,
        videoKbps: nil, audioKbps: audioKbps, audioChannels: audioChannels, crf: crf
      )
    }

    let totalKbps = Double(target) * 8 * sizeHeadroom / outputDuration / 1000
    let videoKbps = max(minVideoKbps, Int(totalKbps) - audioKbps)

    for step in resolutionLadder where step < max(width, height) {
      if bitsPerPixel(kbps: videoKbps, width: width, height: height, fps: fps) >= minBitsPerPixel {
        break
      }
      (width, height) = scaled(source: source, longestSide: step)
    }

    return EncodePlan(
      mode: .encode, width: width, height: height, fps: fps,
      videoKbps: videoKbps, audioKbps: audioKbps, audioChannels: audioChannels, crf: crf
    )
  }

  static func bitsPerPixel(kbps: Int, width: Int, height: Int, fps: Int) -> Double {
    Double(kbps) * 1000 / (Double(width) * Double(height) * Double(fps))
  }

  private static func audioBudget(source: MediaInfo, mode: AudioMode) -> (Int, Int?) {
    guard source.hasAudio else { return (0, nil) }
    switch mode {
    case .strip:
      return (0, nil)
    case .mono:
      return (monoAudioKbps, 1)
    case .keep:
      return (stereoAudioKbps, nil)
    }
  }

  /// Fits the source into `longestSide` keeping aspect ratio; libx264 + yuv420p need even dimensions.
  private static func scaled(source: MediaInfo, longestSide: Int?) -> (Int, Int) {
    let longest = max(source.width, source.height)
    guard let limit = longestSide, limit < longest else {
      return (floorEven(source.width), floorEven(source.height))
    }
    let factor = Double(limit) / Double(longest)
    return (roundEven(Double(source.width) * factor), roundEven(Double(source.height) * factor))
  }

  private static func shouldRemux(source: MediaInfo, settings: CompressSettings, edited: Bool, fps: Int, width: Int) -> Bool {
    guard !edited, source.videoCodec == "h264", source.isMP4Family else { return false }
    if let target = settings.targetBytes, source.sizeBytes > target { return false }
    if settings.targetBytes == nil { return false }
    let withinResolution = width == floorEven(source.width)
    let withinFps = source.fps <= Double(settings.fpsCap) + 0.5
    let audioOk = !(source.hasAudio && settings.audio == .strip)
    return withinResolution && withinFps && audioOk
  }

  private static func floorEven(_ value: Int) -> Int {
    max(2, value - value % 2)
  }

  private static func roundEven(_ value: Double) -> Int {
    max(2, Int((value / 2).rounded()) * 2)
  }
}
