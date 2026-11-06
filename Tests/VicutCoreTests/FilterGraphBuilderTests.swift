import Testing
@testable import VicutCore

struct FilterGraphBuilderTests {
  private let output = FilterGraphBuilder.OutputFormat(width: 1280, height: 800, fps: 30)

  @Test func uneditedClipOnlyScales() {
    let graph = FilterGraphBuilder.build(
      segments: [Segment(start: 0, end: 10, action: .keep)],
      sourceDuration: 10, includeAudio: true, muteSpedUp: true, output: output
    )
    #expect(graph.graph == "[0:v:0]scale=1280:800:flags=lanczos,fps=30,format=yuv420p[vout]")
    #expect(graph.videoOutput == "[vout]")
    #expect(graph.audioOutput == "0:a:0")
  }

  @Test func uneditedClipWithoutAudio() {
    let graph = FilterGraphBuilder.build(
      segments: [Segment(start: 0, end: 10, action: .keep)],
      sourceDuration: 10, includeAudio: false, muteSpedUp: true, output: output
    )
    #expect(graph.audioOutput == nil)
  }

  @Test func singleTrimmedSegmentWithoutAudio() {
    let graph = FilterGraphBuilder.build(
      segments: [Segment(start: 2, end: 5.5, action: .keep)],
      sourceDuration: 100, includeAudio: false, muteSpedUp: true, output: output
    )
    #expect(graph.graph == """
    [0:v:0]trim=start=2.000:end=5.500,setpts=PTS-STARTPTS[v0];\
    [v0]concat=n=1:v=1:a=0[vc];\
    [vc]scale=1280:800:flags=lanczos,fps=30,format=yuv420p[vout]
    """)
    #expect(graph.audioOutput == nil)
  }

  @Test func multipleSegmentsWithSpeedAndMutedAudio() {
    let graph = FilterGraphBuilder.build(
      segments: [
        Segment(start: 0, end: 10, action: .keep),
        Segment(start: 30, end: 70, action: .speed(4))
      ],
      sourceDuration: 100, includeAudio: true, muteSpedUp: true, output: output
    )
    #expect(graph.graph == """
    [0:v:0]split=2[vs0][vs1];\
    [0:a:0]asplit=2[as0][as1];\
    [vs0]trim=start=0.000:end=10.000,setpts=PTS-STARTPTS[v0];\
    [as0]atrim=start=0.000:end=10.000,asetpts=PTS-STARTPTS[a0];\
    [vs1]trim=start=30.000:end=70.000,setpts=(PTS-STARTPTS)/4[v1];\
    [as1]atrim=start=30.000:end=70.000,asetpts=PTS-STARTPTS,atempo=4,volume=0[a1];\
    [v0][a0][v1][a1]concat=n=2:v=1:a=1[vc][aout];\
    [vc]scale=1280:800:flags=lanczos,fps=30,format=yuv420p[vout]
    """)
    #expect(graph.audioOutput == "[aout]")
  }

  @Test func speedAudioNotMutedWhenDisabledAndFractionalSpeed() {
    let graph = FilterGraphBuilder.build(
      segments: [Segment(start: 1, end: 3, action: .speed(1.5))],
      sourceDuration: 100, includeAudio: true, muteSpedUp: false, output: output
    )
    #expect(graph.graph.contains("setpts=(PTS-STARTPTS)/1.5[v0]"))
    #expect(graph.graph.contains("atempo=1.5[a0]"))
    #expect(!graph.graph.contains("volume=0"))
  }
}

struct FilterGraphBuilderTailCutTests {
  @Test func keepFromZeroButShorterThanSourceIsTrimmed() {
    let graph = FilterGraphBuilder.build(
      segments: [Segment(start: 0, end: 8, action: .keep)],
      sourceDuration: 10, includeAudio: false, muteSpedUp: true,
      output: .init(width: 640, height: 400, fps: 30)
    )
    #expect(graph.graph.contains("trim=start=0.000:end=8.000"))
  }
}
