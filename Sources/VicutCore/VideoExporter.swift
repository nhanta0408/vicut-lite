import Foundation

public struct ExportRequest: Sendable {
  public let input: URL
  public let output: URL
  public let marks: [Segment]
  public let settings: CompressSettings

  public init(input: URL, output: URL, marks: [Segment], settings: CompressSettings) {
    self.input = input
    self.output = output
    self.marks = marks
    self.settings = settings
  }
}

public struct ExportResult: Sendable {
  public let output: URL
  public let bytes: Int64
  public let source: MediaInfo
  public let plan: EncodePlan
  /// True when even the 2-pass encode overshot the target (extremely long clips).
  public let exceedsTarget: Bool
}

/// Orchestrates probe → timeline → bitrate plan → ffmpeg encode (CRF first, 2-pass fallback).
public struct VideoExporter: Sendable {
  /// Share of the progress bar given to the CRF attempt when a 2-pass fallback may follow.
  static let crfProgressShare = 0.4

  private let tools: FFmpegTools
  private let temporaryRoot: URL

  public init(tools: FFmpegTools, temporaryRoot: URL = FileManager.default.temporaryDirectory) {
    self.tools = tools
    self.temporaryRoot = temporaryRoot
  }

  public func export(
    _ request: ExportRequest,
    source: MediaInfo? = nil,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> ExportResult {
    let info: MediaInfo
    if let source {
      info = source
    } else {
      info = try await Probe.run(request.input, tools: tools)
    }
    let segments = try Timeline.normalize(marks: request.marks, duration: info.duration)
    let edited = !Timeline.isUnedited(segments, duration: info.duration)
    let outputDuration = Timeline.outputDuration(segments)
    let plan = BitratePlanner.plan(source: info, outputDuration: outputDuration, settings: request.settings, edited: edited)

    let workDir = temporaryRoot.appendingPathComponent("vicut-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workDir) }
    let staged = workDir.appendingPathComponent("out.mp4")

    if plan.mode == .remux {
      let args = EncodeCommandBuilder.remuxArguments(
        input: request.input, output: staged, includeAudio: info.hasAudio && plan.audioKbps > 0
      )
      try await runFFmpeg(args, duration: outputDuration, range: 0...1, progress: progress)
    } else {
      let graph = FilterGraphBuilder.build(
        segments: segments,
        sourceDuration: info.duration,
        includeAudio: info.hasAudio && plan.audioKbps > 0,
        muteSpedUp: request.settings.muteSpedUpAudio,
        output: .init(width: plan.width, height: plan.height, fps: plan.fps)
      )
      try await encode(request: request, graph: graph, plan: plan, staged: staged, workDir: workDir,
                       duration: outputDuration, progress: progress)
    }

    let bytes = try fileSize(staged)
    try FileManager.default.moveItem(at: staged, to: request.output)
    progress(1)
    return ExportResult(
      output: request.output,
      bytes: bytes,
      source: info,
      plan: plan,
      exceedsTarget: request.settings.targetBytes.map { bytes > $0 } ?? false
    )
  }

  private func encode(
    request: ExportRequest,
    graph: FilterGraph,
    plan: EncodePlan,
    staged: URL,
    workDir: URL,
    duration: Double,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    if request.settings.resolvedEncoder == .light {
      try await encodeWithVideoToolbox(request: request, graph: graph, plan: plan, staged: staged,
                                       duration: duration, progress: progress)
      return
    }
    let crfArgs = EncodeCommandBuilder.crfArguments(input: request.input, output: staged, graph: graph, plan: plan)
    guard let target = request.settings.targetBytes else {
      try await runFFmpeg(crfArgs, duration: duration, range: 0...1, progress: progress)
      return
    }

    let crfEnd = Self.crfProgressShare
    try await runFFmpeg(crfArgs, duration: duration, range: 0...crfEnd, progress: progress)
    if try fileSize(staged) <= target {
      return
    }

    // CRF overshot the budget: 2-pass ABR hits the requested bitrate precisely.
    try FileManager.default.removeItem(at: staged)
    let passLog = workDir.appendingPathComponent("pass")
    let passMid = crfEnd + (1 - crfEnd) / 2
    for (pass, range) in [(1, crfEnd...passMid), (2, passMid...1)] {
      let args = EncodeCommandBuilder.twoPassArguments(
        pass: pass, input: request.input, output: staged, graph: graph, plan: plan, passLog: passLog
      )
      try await runFFmpeg(args, duration: duration, range: range, progress: progress)
    }
  }

  /// Same shape as the x264 path: quality first, re-encode at the planned bitrate only if it overshoots.
  private func encodeWithVideoToolbox(
    request: ExportRequest,
    graph: FilterGraph,
    plan: EncodePlan,
    staged: URL,
    duration: Double,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    let qualityArgs = EncodeCommandBuilder.videoToolboxQualityArguments(
      input: request.input, output: staged, graph: graph, plan: plan
    )
    guard let target = request.settings.targetBytes, plan.videoKbps != nil else {
      try await runFFmpeg(qualityArgs, duration: duration, range: 0...1, progress: progress)
      return
    }
    let qualityEnd = Self.crfProgressShare
    try await runFFmpeg(qualityArgs, duration: duration, range: 0...qualityEnd, progress: progress)
    if try fileSize(staged) <= target {
      return
    }
    try FileManager.default.removeItem(at: staged)
    let bitrateArgs = EncodeCommandBuilder.videoToolboxBitrateArguments(
      input: request.input, output: staged, graph: graph, plan: plan
    )
    try await runFFmpeg(bitrateArgs, duration: duration, range: qualityEnd...1, progress: progress)
  }

  private func runFFmpeg(
    _ arguments: [String],
    duration: Double,
    range: ClosedRange<Double>,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    let parser = LockedParser(ProgressParser(totalDuration: duration))
    let span = range.upperBound - range.lowerBound
    let result = try await ProcessRunner.run(executable: tools.ffmpeg, arguments: arguments) { line in
      if let fraction = parser.consume(line) {
        progress(range.lowerBound + fraction * span)
      }
    }
    guard result.exitCode == 0 else {
      throw FFmpegError.failed(exitCode: result.exitCode, log: result.stderrTail)
    }
  }

  private func fileSize(_ url: URL) throws -> Int64 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.size] as? NSNumber)?.int64Value ?? 0
  }
}

private final class LockedParser: @unchecked Sendable {
  private let lock = NSLock()
  private var parser: ProgressParser

  init(_ parser: ProgressParser) {
    self.parser = parser
  }

  func consume(_ line: String) -> Double? {
    lock.lock()
    defer { lock.unlock() }
    return parser.consume(line: line)
  }
}
