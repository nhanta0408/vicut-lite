import Foundation

public struct FFmpegTools: Sendable, Equatable {
  public let ffmpeg: URL
  public let ffprobe: URL

  public init(ffmpeg: URL, ffprobe: URL) {
    self.ffmpeg = ffmpeg
    self.ffprobe = ffprobe
  }
}

public enum FFmpegError: Error, Equatable {
  case notFound
  case failed(exitCode: Int32, log: [String])
}

public enum FFmpegLocator {
  public static let environmentKey = "VICUT_FFMPEG_DIR"

  /// Order: explicit env override (dev/tests) → binaries bundled in the .app → Homebrew (dev convenience).
  public static func locate(
    bundle: Bundle = .main,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) throws -> FFmpegTools {
    var candidates: [URL] = []
    if let dir = environment[environmentKey], !dir.isEmpty {
      candidates.append(URL(fileURLWithPath: dir, isDirectory: true))
    }
    if let resources = bundle.resourceURL {
      candidates.append(resources.appendingPathComponent("bin", isDirectory: true))
    }
    candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true))
    candidates.append(URL(fileURLWithPath: "/usr/local/bin", isDirectory: true))

    for dir in candidates {
      let ffmpeg = dir.appendingPathComponent("ffmpeg")
      let ffprobe = dir.appendingPathComponent("ffprobe")
      if fileManager.isExecutableFile(atPath: ffmpeg.path), fileManager.isExecutableFile(atPath: ffprobe.path) {
        return FFmpegTools(ffmpeg: ffmpeg, ffprobe: ffprobe)
      }
    }
    throw FFmpegError.notFound
  }
}
