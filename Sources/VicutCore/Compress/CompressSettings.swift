import Foundation

public enum AudioMode: String, Codable, CaseIterable, Sendable {
  case keep
  case mono
  case strip
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

  public init(
    targetBytes: Int64?,
    maxDimension: Int?,
    fpsCap: Int,
    audio: AudioMode,
    muteSpedUpAudio: Bool,
    outputSuffix: String,
    crf: Int? = nil
  ) {
    self.targetBytes = targetBytes
    self.maxDimension = maxDimension
    self.fpsCap = fpsCap
    self.audio = audio
    self.muteSpedUpAudio = muteSpedUpAudio
    self.outputSuffix = outputSuffix
    self.crf = crf
  }

  /// GitHub's free-plan attachment limit is 10 MB; decimal bytes keeps us safely under it.
  public static let githubLimitBytes: Int64 = 10_000_000

  public static let `default` = CompressSettings(
    targetBytes: githubLimitBytes,
    maxDimension: 1920,
    fpsCap: 30,
    audio: .mono,
    muteSpedUpAudio: true,
    outputSuffix: "-vicut"
  )

  /// Visually lossless for screen content; much bigger than the compressed preset.
  public static let fullQualityCrf = 18
  static let fullQualityFpsCap = 60

  /// Edit-only export: source resolution and frame rate, stereo audio, no size target.
  public static func fullQuality(muteSpedUpAudio: Bool) -> CompressSettings {
    CompressSettings(
      targetBytes: nil,
      maxDimension: nil,
      fpsCap: fullQualityFpsCap,
      audio: .keep,
      muteSpedUpAudio: muteSpedUpAudio,
      outputSuffix: "-edited",
      crf: fullQualityCrf
    )
  }
}
