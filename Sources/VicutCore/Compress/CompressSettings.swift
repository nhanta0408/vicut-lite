import Foundation

public enum AudioMode: String, Codable, CaseIterable, Sendable {
  case keep
  case mono
  case strip
}

/// Trade-off between encode speed / file size and how hard the machine works.
public enum EncoderMode: String, Codable, CaseIterable, Sendable {
  /// libx264 on every CPU core: smallest file for the quality, fastest on a free machine.
  case fast
  /// Apple's hardware decoder + encoder (VideoToolbox): well under one core, a bit slower,
  /// slightly larger files at the same quality.
  case light
}

public struct CompressSettings: Codable, Equatable, Sendable {
  /// nil = no size limit (quality-based encode only).
  public var targetBytes: Int64?
  /// Longest side cap in pixels; nil = keep source resolution.
  public var maxDimension: Int?
  public var fpsCap: Int
  public var audio: AudioMode
  public var muteSpedUpAudio: Bool
  public var outputSuffix: String
  /// x264 quality; nil = EncodePlan.defaultCrf. Optional so settings saved by older builds still decode.
  public var crf: Int?
  /// nil = `.fast`. Optional so settings saved by older builds still decode.
  public var encoder: EncoderMode?

  public var resolvedEncoder: EncoderMode { encoder ?? .fast }

  public init(
    targetBytes: Int64?,
    maxDimension: Int?,
    fpsCap: Int,
    audio: AudioMode,
    muteSpedUpAudio: Bool,
    outputSuffix: String,
    crf: Int? = nil,
    encoder: EncoderMode? = nil
  ) {
    self.targetBytes = targetBytes
    self.maxDimension = maxDimension
    self.fpsCap = fpsCap
    self.audio = audio
    self.muteSpedUpAudio = muteSpedUpAudio
    self.outputSuffix = outputSuffix
    self.crf = crf
    self.encoder = encoder
  }

  /// GitHub's free-plan attachment limit is 10 MB; decimal bytes keeps us safely under it.
  public static let githubLimitBytes: Int64 = 10_000_000

  public static let `default` = CompressSettings(
    targetBytes: githubLimitBytes,
    maxDimension: maxDimension1080p,
    fpsCap: 30,
    audio: .mono,
    muteSpedUpAudio: true,
    outputSuffix: "-vicut"
  )

  /// Size presets offered in Settings besides `githubLimitBytes` (decimal MB, like Finder shows).
  public static let smallTargetBytes: Int64 = 5_000_000
  public static let largeTargetBytes: Int64 = 25_000_000

  /// Longest-side caps offered in Settings.
  public static let maxDimension1080p = 1920
  public static let maxDimension720p = 1280

  /// Frame-rate caps offered in Settings.
  public static let fpsPresets = [15, 30, 60]

  public var isDefault: Bool { self == .default }

  /// Keeps names short enough that long recording names plus suffix stay under the 255-byte file name limit.
  public static let maxSuffixLength = 40

  /// The suffix is spliced into a file name, so path separators, Finder's ":" and control characters
  /// would write outside the source folder or fail; they are dropped as the user types.
  public static func sanitizedSuffix(_ raw: String) -> String {
    let forbidden = CharacterSet(charactersIn: "/:").union(.newlines).union(.controlCharacters)
    let kept = raw.unicodeScalars.filter { !forbidden.contains($0) }
    return String(String.UnicodeScalarView(kept).prefix(maxSuffixLength))
  }

  /// Visually lossless for screen content; much bigger than the compressed preset.
  public static let fullQualityCrf = 18
  static let fullQualityFpsCap = 60

  /// Edit-only export: source resolution and frame rate, stereo audio, no size target.
  public static func fullQuality(muteSpedUpAudio: Bool, encoder: EncoderMode = .fast) -> CompressSettings {
    CompressSettings(
      targetBytes: nil,
      maxDimension: nil,
      fpsCap: fullQualityFpsCap,
      audio: .keep,
      muteSpedUpAudio: muteSpedUpAudio,
      outputSuffix: "-edited",
      crf: fullQualityCrf,
      encoder: encoder
    )
  }
}
