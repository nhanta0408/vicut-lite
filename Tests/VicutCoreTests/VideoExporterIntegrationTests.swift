import Foundation
import Testing
@testable import VicutCore

/// Runs the real ffmpeg binary. Skipped when no ffmpeg is available.
@Suite(.serialized, .enabled(if: (try? FFmpegLocator.locate()) != nil))
struct VideoExporterIntegrationTests {
  private static let sourceDuration = 40.0

  private let tools: FFmpegTools
  private let workDir: URL
  private let tempRoot: URL

  init() throws {
    tools = try FFmpegLocator.locate()
    workDir = FileManager.default.temporaryDirectory.appendingPathComponent("vicut-it-\(UUID().uuidString)")
    tempRoot = workDir.appendingPathComponent("tmp")
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
  }

  /// Fake Retina-ish screen recording: big, high bitrate, with audio — well above 10 MB.
  private func makeSample(name: String = "Screen Recording.mov") async throws -> URL {
    let url = workDir.appendingPathComponent(name)
    let result = try await ProcessRunner.run(executable: tools.ffmpeg, arguments: [
      "-hide_banner", "-loglevel", "error", "-y",
      "-f", "lavfi", "-i", "testsrc2=size=1440x900:rate=60",
      "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
      "-t", "\(Self.sourceDuration)",
      "-c:v", "libx264", "-preset", "ultrafast", "-crf", "10",
      "-c:a", "aac", url.path
    ])
    try #require(result.exitCode == 0, "sample generation failed: \(result.stderrTail)")
    return url
  }

  private func cleanup() {
    try? FileManager.default.removeItem(at: workDir)
  }

  private func fileSize(_ url: URL) throws -> Int64 {
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attrs[.size] as? NSNumber)?.int64Value ?? 0
  }

  private func hasFastStart(_ url: URL) throws -> Bool {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let head = try handle.read(upToCount: 256 * 1024) ?? Data()
    guard let moov = head.range(of: Data("moov".utf8)) else { return false }
    guard let mdat = head.range(of: Data("mdat".utf8)) else { return true }
    return moov.lowerBound < mdat.lowerBound
  }

  @Test func compressesUnderTenMegabytes() async throws {
    defer { cleanup() }
    let input = try await makeSample()
    #expect(try fileSize(input) > CompressSettings.githubLimitBytes)

    let output = OutputNamer.uniqueOutput(for: input, suffix: "-vicut")
    let exporter = VideoExporter(tools: tools, temporaryRoot: tempRoot)
    let recorder = ProgressRecorder()
    let result = try await exporter.export(
      ExportRequest(input: input, output: output, marks: [], settings: .default),
      progress: { recorder.record($0) }
    )

    #expect(result.output == output)
    #expect(result.bytes <= CompressSettings.githubLimitBytes)
    #expect(result.exceedsTarget == false)
    #expect(try hasFastStart(output))

    let info = try await Probe.run(output, tools: tools)
    #expect(info.videoCodec == "h264")
    #expect(info.hasAudio)
    #expect(abs(info.duration - Self.sourceDuration) < 0.3)
    #expect(info.fps <= 30.5)
    #expect(recorder.last == 1)
    #expect(try FileManager.default.contentsOfDirectory(atPath: tempRoot.path).isEmpty)
  }

  @Test func cutAndSpeedProduceExpectedDuration() async throws {
    defer { cleanup() }
    let input = try await makeSample()
    let output = OutputNamer.uniqueOutput(for: input, suffix: "-edit")
    let marks = [
      Segment(start: 5, end: 15, action: .cut),
      Segment(start: 15, end: 35, action: .speed(4))
    ]
    let exporter = VideoExporter(tools: tools, temporaryRoot: tempRoot)
    let result = try await exporter.export(
      ExportRequest(input: input, output: output, marks: marks, settings: .default),
      progress: { _ in }
    )

    let info = try await Probe.run(output, tools: tools)
    // 5s keep + 20s/4 + 5s keep = 15s
    #expect(abs(info.duration - 15) < 0.3)
    #expect(info.hasAudio)
    #expect(result.bytes <= CompressSettings.githubLimitBytes)
  }

  @Test func fullQualityExportKeepsSourceResolutionAndFps() async throws {
    defer { cleanup() }
    let input = try await makeSample()
    let output = OutputNamer.uniqueOutput(for: input, suffix: "-full")
    let marks = [Segment(start: 10, end: 30, action: .speed(4))]
    let exporter = VideoExporter(tools: tools, temporaryRoot: tempRoot)
    let result = try await exporter.export(
      ExportRequest(input: input, output: output, marks: marks, settings: .fullQuality(muteSpedUpAudio: true)),
      progress: { _ in }
    )

    let info = try await Probe.run(output, tools: tools)
    // 10s + 20s/4 + 10s = 25s
    #expect(abs(info.duration - 25) < 0.3)
    #expect(info.width == 1440)
    #expect(info.height == 900)
    #expect(info.fps > 59)
    #expect(info.hasAudio)
    #expect(result.exceedsTarget == false)
  }

  @Test func cancellationLeavesNoFiles() async throws {
    defer { cleanup() }
    let input = try await makeSample()
    let output = OutputNamer.uniqueOutput(for: input, suffix: "-cancel")
    var settings = CompressSettings.default
    settings.maxDimension = nil
    let exporter = VideoExporter(tools: tools, temporaryRoot: tempRoot)
    let task = Task {
      try await exporter.export(
        ExportRequest(input: input, output: output, marks: [], settings: settings),
        progress: { _ in }
      )
    }
    try await Task.sleep(for: .milliseconds(700))
    task.cancel()
    await #expect(throws: CancellationError.self) {
      _ = try await task.value
    }
    #expect(!FileManager.default.fileExists(atPath: output.path))
    #expect(try FileManager.default.contentsOfDirectory(atPath: tempRoot.path).isEmpty)
  }
}

final class ProgressRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [Double] = []

  func record(_ value: Double) {
    lock.lock()
    values.append(value)
    lock.unlock()
  }

  var last: Double? {
    lock.lock()
    defer { lock.unlock() }
    return values.last
  }
}
