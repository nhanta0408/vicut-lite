import AppKit
import Foundation
import Observation
import VicutCore

@MainActor
@Observable
final class Job: Identifiable {
  enum State {
    case queued
    case running(Double)
    case done(ExportResult)
    case failed(message: String, log: [String])
    case cancelled
  }

  enum Kind {
    case compress
    case exportFullQuality
    case exportCompressed

    var verb: String {
      switch self {
      case .compress: "Compressing"
      case .exportFullQuality, .exportCompressed: "Exporting"
      }
    }
  }

  let id = UUID()
  let input: URL
  let marks: [Segment]
  let kind: Kind
  /// Snapshot at enqueue time so later Settings changes don't alter a queued job.
  let settings: CompressSettings
  var state: State = .queued
  let originalBytes: Int64
  @ObservationIgnored var task: Task<ExportResult, Error>?

  init(input: URL, marks: [Segment], kind: Kind, settings: CompressSettings) {
    self.input = input
    self.marks = marks
    self.kind = kind
    self.settings = settings
    let attributes = try? FileManager.default.attributesOfItem(atPath: input.path)
    originalBytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
  }

  var isFinished: Bool {
    switch state {
    case .done, .failed, .cancelled: true
    case .queued, .running: false
    }
  }
}

/// Runs exports one at a time so a batch drop doesn't fight over CPU.
@MainActor
@Observable
final class JobQueue {
  static let supportedExtensions: Set<String> = ["mov", "mp4", "m4v", "mkv", "webm", "avi"]

  private(set) var jobs: [Job] = []
  @ObservationIgnored private let settings: SettingsStore
  @ObservationIgnored private var worker: Task<Void, Never>?
  /// Fires once per successful export (History records it).
  @ObservationIgnored var onJobFinished: ((Job, ExportResult) -> Void)?

  init(settings: SettingsStore) {
    self.settings = settings
  }

  static func isSupported(_ url: URL) -> Bool {
    supportedExtensions.contains(url.pathExtension.lowercased())
  }

  /// Plain compression with the user's Settings.
  func enqueue(_ urls: [URL]) {
    let accepted = urls.filter(Self.isSupported)
    let snapshot = settings.settings
    jobs.insert(contentsOf: accepted.map { Job(input: $0, marks: [], kind: .compress, settings: snapshot) }, at: 0)
    startWorkerIfNeeded()
  }

  /// Export from the editor; `fullQuality` skips the size target entirely.
  func enqueueExport(_ url: URL, marks: [Segment], fullQuality: Bool) {
    let current = settings.settings
    let job = fullQuality
      ? Job(input: url, marks: marks, kind: .exportFullQuality,
            settings: .fullQuality(muteSpedUpAudio: current.muteSpedUpAudio))
      : Job(input: url, marks: marks, kind: .exportCompressed, settings: current)
    jobs.insert(job, at: 0)
    startWorkerIfNeeded()
  }

  func cancel(_ job: Job) {
    if case .queued = job.state {
      job.state = .cancelled
    }
    job.task?.cancel()
  }

  func remove(_ job: Job) {
    cancel(job)
    jobs.removeAll { $0.id == job.id }
  }

  func clearFinished() {
    jobs.removeAll(where: \.isFinished)
  }

  private func startWorkerIfNeeded() {
    guard worker == nil else { return }
    worker = Task { [weak self] in
      while let self, let next = self.nextQueued() {
        await self.run(next)
      }
      self?.worker = nil
    }
  }

  private func nextQueued() -> Job? {
    jobs.last { if case .queued = $0.state { true } else { false } }
  }

  private func run(_ job: Job) async {
    let tools: FFmpegTools
    do {
      tools = try FFmpegLocator.locate()
    } catch {
      job.state = .failed(message: "ffmpeg not found. Reinstall ViCut Lite or run `brew install ffmpeg`.", log: [])
      return
    }

    job.state = .running(0)
    let settings = job.settings
    let output = OutputNamer.uniqueOutput(for: job.input, suffix: settings.outputSuffix)
    let request = ExportRequest(input: job.input, output: output, marks: job.marks, settings: settings)
    let exporter = VideoExporter(tools: tools)
    let task = Task.detached {
      try await exporter.export(request) { fraction in
        Task { @MainActor in
          if case .running = job.state {
            job.state = .running(fraction)
          }
        }
      }
    }
    job.task = task

    do {
      let result = try await task.value
      job.state = .done(result)
      onJobFinished?(job, result)
    } catch is CancellationError {
      job.state = .cancelled
    } catch let FFmpegError.failed(exitCode, log) {
      job.state = .failed(message: "ffmpeg exited with code \(exitCode).", log: log)
    } catch ProbeError.noVideoStream {
      job.state = .failed(message: "This file has no video track.", log: [])
    } catch TimelineError.emptyOutput {
      job.state = .failed(message: "Every part of the clip is cut — nothing to export.", log: [])
    } catch {
      job.state = .failed(message: error.localizedDescription, log: [])
    }
    job.task = nil
  }
}
