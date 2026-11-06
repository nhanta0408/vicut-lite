import Foundation

public struct FilterGraph: Sendable, Equatable {
  public let graph: String
  /// Filter label to `-map` for video.
  public let videoOutput: String
  /// Filter label or input stream specifier to `-map` for audio; nil = no audio.
  public let audioOutput: String?

  public init(graph: String, videoOutput: String, audioOutput: String?) {
    self.graph = graph
    self.videoOutput = videoOutput
    self.audioOutput = audioOutput
  }
}

public enum FilterGraphBuilder {
  public struct OutputFormat: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let fps: Int

    public init(width: Int, height: Int, fps: Int) {
      self.width = width
      self.height = height
      self.fps = fps
    }
  }

  /// `segments` must already be normalized (kept segments only, in order).
  public static func build(
    segments: [Segment],
    sourceDuration: Double,
    includeAudio: Bool,
    muteSpedUp: Bool,
    output: OutputFormat
  ) -> FilterGraph {
    // fps runs after concat so sped-up parts drop surplus frames instead of inflating the bitrate.
    let finish = "scale=\(output.width):\(output.height):flags=lanczos,fps=\(output.fps),format=yuv420p[vout]"

    if Timeline.isUnedited(segments, duration: sourceDuration) {
      return FilterGraph(
        graph: "[0:v:0]\(finish)",
        videoOutput: "[vout]",
        audioOutput: includeAudio ? "0:a:0" : nil
      )
    }

    var chains: [String] = []
    let count = segments.count
    let videoInputs: [String]
    let audioInputs: [String]
    if count > 1 {
      videoInputs = (0..<count).map { "[vs\($0)]" }
      chains.append("[0:v:0]split=\(count)\(videoInputs.joined())")
      audioInputs = (0..<count).map { "[as\($0)]" }
      if includeAudio {
        chains.append("[0:a:0]asplit=\(count)\(audioInputs.joined())")
      }
    } else {
      videoInputs = ["[0:v:0]"]
      audioInputs = ["[0:a:0]"]
    }

    var concatInputs = ""
    for (index, segment) in segments.enumerated() {
      let range = "start=\(time(segment.start)):end=\(time(segment.end))"
      let rate = segment.action.playbackRate
      let setpts = rate == 1 ? "setpts=PTS-STARTPTS" : "setpts=(PTS-STARTPTS)/\(number(rate))"
      chains.append("\(videoInputs[index])trim=\(range),\(setpts)[v\(index)]")
      concatInputs += "[v\(index)]"

      if includeAudio {
        var audio = "\(audioInputs[index])atrim=\(range),asetpts=PTS-STARTPTS"
        if rate != 1 {
          audio += ",atempo=\(number(rate))"
          if muteSpedUp {
            audio += ",volume=0"
          }
        }
        chains.append("\(audio)[a\(index)]")
        concatInputs += "[a\(index)]"
      }
    }

    let audioFlag = includeAudio ? 1 : 0
    let concatOutputs = includeAudio ? "[vc][aout]" : "[vc]"
    chains.append("\(concatInputs)concat=n=\(count):v=1:a=\(audioFlag)\(concatOutputs)")
    chains.append("[vc]\(finish)")

    return FilterGraph(
      graph: chains.joined(separator: ";"),
      videoOutput: "[vout]",
      audioOutput: includeAudio ? "[aout]" : nil
    )
  }

  private static func time(_ seconds: Double) -> String {
    String(format: "%.3f", seconds)
  }

  private static func number(_ value: Double) -> String {
    String(format: "%g", value)
  }
}
