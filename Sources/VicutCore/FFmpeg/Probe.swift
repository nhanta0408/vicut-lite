import Foundation

public enum ProbeError: Error, Equatable {
  case noVideoStream
  case invalidDuration
  case malformedOutput
}

public enum Probe {
  public static func run(_ input: URL, tools: FFmpegTools) async throws -> MediaInfo {
    let result = try await ProcessRunner.run(
      executable: tools.ffprobe,
      arguments: ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", input.path]
    )
    guard result.exitCode == 0 else {
      throw FFmpegError.failed(exitCode: result.exitCode, log: result.stderrTail)
    }
    return try parse(json: result.stdout)
  }

  public static func parse(json: Data) throws -> MediaInfo {
    let decoded: ProbeOutput
    do {
      decoded = try JSONDecoder().decode(ProbeOutput.self, from: json)
    } catch {
      throw ProbeError.malformedOutput
    }
    guard let video = decoded.streams.first(where: { $0.codecType == "video" }),
          let width = video.width,
          let height = video.height
    else {
      throw ProbeError.noVideoStream
    }
    guard let duration = decoded.format.duration.flatMap(Double.init), duration > 0 else {
      throw ProbeError.invalidDuration
    }

    let quarterTurn = abs(video.rotation).truncatingRemainder(dividingBy: 180) == 90
    let fps = parseRate(video.avgFrameRate) ?? parseRate(video.rFrameRate) ?? 30

    return MediaInfo(
      duration: duration,
      width: quarterTurn ? height : width,
      height: quarterTurn ? width : height,
      fps: fps,
      hasAudio: decoded.streams.contains { $0.codecType == "audio" },
      videoCodec: video.codecName ?? "unknown",
      formatName: decoded.format.formatName ?? "",
      sizeBytes: decoded.format.size.flatMap { Int64($0) } ?? 0
    )
  }

  static func parseRate(_ raw: String?) -> Double? {
    guard let raw else { return nil }
    let parts = raw.split(separator: "/").compactMap { Double($0) }
    if parts.count == 2, parts[1] != 0, parts[0] > 0 {
      return parts[0] / parts[1]
    }
    if parts.count == 1, parts[0] > 0 {
      return parts[0]
    }
    return nil
  }
}

private struct ProbeOutput: Decodable {
  struct Stream: Decodable {
    struct SideData: Decodable {
      let rotation: Double?
    }

    let codecType: String?
    let codecName: String?
    let width: Int?
    let height: Int?
    let avgFrameRate: String?
    let rFrameRate: String?
    let sideDataList: [SideData]?
    let tags: [String: String]?

    var rotation: Double {
      if let fromSideData = sideDataList?.compactMap(\.rotation).first {
        return fromSideData
      }
      return tags?["rotate"].flatMap(Double.init) ?? 0
    }

    enum CodingKeys: String, CodingKey {
      case codecType = "codec_type"
      case codecName = "codec_name"
      case width
      case height
      case avgFrameRate = "avg_frame_rate"
      case rFrameRate = "r_frame_rate"
      case sideDataList = "side_data_list"
      case tags
    }
  }

  struct Format: Decodable {
    let formatName: String?
    let duration: String?
    let size: String?

    enum CodingKeys: String, CodingKey {
      case formatName = "format_name"
      case duration
      case size
    }
  }

  let streams: [Stream]
  let format: Format
}
