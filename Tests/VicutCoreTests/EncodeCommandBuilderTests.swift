import Foundation
import Testing
@testable import VicutCore

struct EncodeCommandBuilderTests {
  private let input = URL(fileURLWithPath: "/in/Screen Recording.mov")
  private let output = URL(fileURLWithPath: "/out/a.mp4")
  private let graph = FilterGraph(graph: "G", videoOutput: "[vout]", audioOutput: "0:a:0")

  private func plan(video: Int?, audio: Int) -> EncodePlan {
    EncodePlan(mode: .encode, width: 1280, height: 800, fps: 30, videoKbps: video, audioKbps: audio, audioChannels: 1)
  }

  @Test func crfWithCapIncludesMaxrateAndAudio() {
    let args = EncodeCommandBuilder.crfArguments(input: input, output: output, graph: graph, plan: plan(video: 1000, audio: 64))
    let joined = args.joined(separator: " ")
    #expect(joined.hasPrefix("-hide_banner -nostats -progress pipe:1 -y -i /in/Screen Recording.mov"))
    #expect(joined.contains("-filter_complex G -map [vout] -map 0:a:0"))
    #expect(joined.contains("-c:v libx264 -preset medium -crf 26 -maxrate 1000k -bufsize 2000k"))
    #expect(joined.contains("-c:a aac -b:a 64k -ac 1"))
    #expect(joined.contains("-movflags +faststart"))
    #expect(args.last == "/out/a.mp4")
  }

  @Test func crfWithoutTargetHasNoMaxrateAndNoAudio() {
    let noAudio = FilterGraph(graph: "G", videoOutput: "[vout]", audioOutput: nil)
    let joined = EncodeCommandBuilder.crfArguments(input: input, output: output, graph: noAudio, plan: plan(video: nil, audio: 0)).joined(separator: " ")
    #expect(!joined.contains("-maxrate"))
    #expect(joined.contains("-an"))
    #expect(!joined.contains("-c:a"))
  }

  @Test func twoPassArguments() {
    let log = URL(fileURLWithPath: "/tmp/x/pass")
    let p1 = EncodeCommandBuilder.twoPassArguments(pass: 1, input: input, output: output, graph: graph, plan: plan(video: 900, audio: 64), passLog: log).joined(separator: " ")
    #expect(p1.contains("-b:v 900k -pass 1 -passlogfile /tmp/x/pass"))
    #expect(p1.contains("-map 0:a:0"))
    #expect(p1.hasSuffix("-f mp4 /dev/null"))
    let p2 = EncodeCommandBuilder.twoPassArguments(pass: 2, input: input, output: output, graph: graph, plan: plan(video: 900, audio: 64), passLog: log).joined(separator: " ")
    #expect(p2.contains("-b:v 900k -pass 2 -passlogfile /tmp/x/pass"))
    #expect(p2.contains("-c:a aac -b:a 64k -ac 1"))
    #expect(p2.hasSuffix("/out/a.mp4"))
  }

  @Test func remuxCopiesStreams() {
    let joined = EncodeCommandBuilder.remuxArguments(input: input, output: output, includeAudio: true).joined(separator: " ")
    #expect(joined.contains("-map 0:v:0 -map 0:a:0? -c copy -tag:v avc1 -movflags +faststart"))
  }

  @Test func crfComesFromPlan() {
    var highQuality = plan(video: nil, audio: 128)
    highQuality.crf = 18
    let joined = EncodeCommandBuilder.crfArguments(input: input, output: output, graph: graph, plan: highQuality).joined(separator: " ")
    #expect(joined.contains("-crf 18"))
  }
}

