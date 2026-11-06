import Foundation
import Testing
@testable import VicutCore

struct ProbeTests {
  private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
  }

  @Test func parsesMovWithAudio() throws {
    let info = try Probe.parse(json: fixture("probe_mov_with_audio"))
    #expect(info.duration == 2.0)
    #expect(info.width == 640)
    #expect(info.height == 400)
    #expect(info.fps == 60)
    #expect(info.hasAudio)
    #expect(info.videoCodec == "h264")
    #expect(info.isMP4Family)
    #expect(info.sizeBytes == 318_774)
  }

  @Test func swapsDimensionsWhenRotatedAndDetectsNoAudio() throws {
    let info = try Probe.parse(json: fixture("probe_rotated_no_audio"))
    #expect(info.width == 1080)
    #expect(info.height == 1920)
    #expect(abs(info.fps - 29.97) < 0.01)
    #expect(info.hasAudio == false)
    #expect(info.videoCodec == "hevc")
  }

  @Test func throwsWhenNoVideoStream() {
    let json = #"{"streams":[{"codec_type":"audio","codec_name":"aac"}],"format":{"format_name":"mp3","duration":"3"}}"#
    #expect(throws: ProbeError.noVideoStream) {
      try Probe.parse(json: Data(json.utf8))
    }
  }
}
