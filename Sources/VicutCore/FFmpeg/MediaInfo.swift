import Foundation

public struct MediaInfo: Sendable, Equatable {
  public var duration: Double
  public var width: Int
  public var height: Int
  public var fps: Double
  public var hasAudio: Bool
  public var videoCodec: String
  public var formatName: String
  public var sizeBytes: Int64

  public init(
    duration: Double,
    width: Int,
    height: Int,
    fps: Double,
    hasAudio: Bool,
    videoCodec: String,
    formatName: String,
    sizeBytes: Int64
  ) {
    self.duration = duration
    self.width = width
    self.height = height
    self.fps = fps
    self.hasAudio = hasAudio
    self.videoCodec = videoCodec
    self.formatName = formatName
    self.sizeBytes = sizeBytes
  }

  public var isMP4Family: Bool {
    formatName.contains("mp4") || formatName.contains("mov")
  }
}
