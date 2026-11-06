import Foundation

public enum EncodeCommandBuilder {
  static let preset = "medium"

  /// VideoToolbox constant quality (`-q:v`, 1–100) that gives about the file size of `EncodePlan.defaultCrf`
  /// on screen recordings; measured on a 1080p60 clip scaled to 720p30.
  static let videoToolboxDefaultQuality = 45
  /// Quality points per CRF step, so full-quality exports (lower CRF) map to a higher `-q:v`.
  static let videoToolboxQualityPerCrf = 2.5
  static let videoToolboxQualityRange = 1...100

  static func videoToolboxQuality(crf: Int) -> Int {
    let raw = Double(videoToolboxDefaultQuality) + Double(EncodePlan.defaultCrf - crf) * videoToolboxQualityPerCrf
    return min(max(Int(raw.rounded()), videoToolboxQualityRange.lowerBound), videoToolboxQualityRange.upperBound)
  }

  /// Hardware encode: constant quality, no size cap. Decoding also runs on the media engine,
  /// otherwise software decode + scaling alone keeps ~5 cores busy.
  public static func videoToolboxQualityArguments(input: URL, output: URL, graph: FilterGraph, plan: EncodePlan) -> [String] {
    let rate = ["-q:v", "\(videoToolboxQuality(crf: plan.crf))"]
    return header(input: input, hardwareDecode: true)
      + mapping(graph: graph)
      + videoToolbox(rate: rate)
      + audio(graph: graph, plan: plan)
      + container(output: output)
  }

  /// Hardware encode at the planned bitrate. VideoToolbox has no 2-pass, so this single pass is the
  /// fallback when the quality encode overshoots the size target; it tends to land under the bitrate.
  public static func videoToolboxBitrateArguments(input: URL, output: URL, graph: FilterGraph, plan: EncodePlan) -> [String] {
    let kbps = plan.videoKbps ?? 0
    let rate = ["-b:v", "\(kbps)k", "-maxrate", "\(kbps)k", "-bufsize", "\(kbps * 2)k"]
    return header(input: input, hardwareDecode: true)
      + mapping(graph: graph)
      + videoToolbox(rate: rate)
      + audio(graph: graph, plan: plan)
      + container(output: output)
  }

  public static func crfArguments(input: URL, output: URL, graph: FilterGraph, plan: EncodePlan) -> [String] {
    var rate = ["-crf", "\(plan.crf)"]
    if let kbps = plan.videoKbps {
      rate += ["-maxrate", "\(kbps)k", "-bufsize", "\(kbps * 2)k"]
    }
    return header(input: input)
      + mapping(graph: graph)
      + video(rate: rate)
      + audio(graph: graph, plan: plan)
      + container(output: output)
  }

  public static func twoPassArguments(
    pass: Int,
    input: URL,
    output: URL,
    graph: FilterGraph,
    plan: EncodePlan,
    passLog: URL
  ) -> [String] {
    let kbps = plan.videoKbps ?? 0
    let rate = ["-b:v", "\(kbps)k", "-pass", "\(pass)", "-passlogfile", passLog.path]
    let base = header(input: input) + mapping(graph: graph) + video(rate: rate) + audio(graph: graph, plan: plan)
    if pass == 1 {
      return base + ["-f", "mp4", "/dev/null"]
    }
    return base + container(output: output)
  }

  public static func remuxArguments(input: URL, output: URL, includeAudio: Bool) -> [String] {
    var args = header(input: input) + ["-map", "0:v:0"]
    if includeAudio {
      args += ["-map", "0:a:0?"]
    }
    return args + ["-c", "copy", "-tag:v", "avc1"] + container(output: output)
  }

  /// `-hwaccel` falls back to software decode by itself when the input codec isn't supported.
  private static func header(input: URL, hardwareDecode: Bool = false) -> [String] {
    let decode = hardwareDecode ? ["-hwaccel", "videotoolbox"] : []
    return ["-hide_banner", "-nostats", "-progress", "pipe:1", "-y"] + decode + ["-i", input.path]
  }

  private static func mapping(graph: FilterGraph) -> [String] {
    var args = ["-filter_complex", graph.graph, "-map", graph.videoOutput]
    if let audio = graph.audioOutput {
      args += ["-map", audio]
    }
    return args
  }

  private static func video(rate: [String]) -> [String] {
    ["-c:v", "libx264", "-preset", preset] + rate + ["-pix_fmt", "yuv420p", "-tag:v", "avc1"]
  }

  private static func videoToolbox(rate: [String]) -> [String] {
    ["-c:v", "h264_videotoolbox"] + rate + ["-pix_fmt", "yuv420p", "-tag:v", "avc1"]
  }

  private static func audio(graph: FilterGraph, plan: EncodePlan) -> [String] {
    guard graph.audioOutput != nil, plan.audioKbps > 0 else { return ["-an"] }
    var args = ["-c:a", "aac", "-b:a", "\(plan.audioKbps)k"]
    if let channels = plan.audioChannels {
      args += ["-ac", "\(channels)"]
    }
    return args
  }

  private static func container(output: URL) -> [String] {
    ["-movflags", "+faststart", output.path]
  }
}
