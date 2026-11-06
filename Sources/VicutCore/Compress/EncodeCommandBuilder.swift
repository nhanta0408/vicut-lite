import Foundation

public enum EncodeCommandBuilder {
  static let preset = "medium"

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

  private static func header(input: URL) -> [String] {
    ["-hide_banner", "-nostats", "-progress", "pipe:1", "-y", "-i", input.path]
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
