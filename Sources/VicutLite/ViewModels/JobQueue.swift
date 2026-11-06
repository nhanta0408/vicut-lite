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
  /// When encoding began; drives the remaining-time estimate.
  var startedAt: Date?
  /// Set once the user moved the source file to the Trash (only the output remains).
  var originalTrashed = false
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

  var isActive: Bool {
    !isFinished
  }

  var result: ExportResult? {
    if case .done(let result) = state { result } else { nil }
  }

  /// Only finished jobs whose source still exists can have their original trashed.
  var canTrashOriginal: Bool {
    result != nil && !originalTrashed
  }
}

/// Runs exports one at a time so a batch drop doesn't fight over CPU.
@MainActor
@Observable
final class JobQueue {
  private(set) var jobs: [Job] = []
  /// Bytes saved by every export finished since launch, kept even after rows are cleared.
  private(set) var sessionSavedBytes: Int64 = 0
  @ObservationIgnored private let settings: SettingsStore
  @ObservationIgnored private var worker: Task<Void, Never>?
  /// Fires once per successful export (History records it).
  @ObservationIgnored var onJobFinished: ((Job, ExportResult) -> Void)?

  init(settings: SettingsStore) {
    self.settings = settings
  }

  static func isSupported(_ url: URL) -> Bool {
    VideoFiles.isSupported(url)
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
            settings: .fullQuality(muteSpedUpAudio: current.muteSpedUpAudio, encoder: current.resolvedEncoder))
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

  /// Moves the source files of finished jobs to the Trash (restorable), keeping the outputs.
  /// Returns the jobs that could not be trashed.
  @discardableResult
  func trashOriginals(_ targets: [Job]) -> [Job] {
    var failed: [Job] = []
    for job in targets where job.canTrashOriginal {
      do {
        try FileManager.default.trashItem(at: job.input, resultingItemURL: nil)
        job.originalTrashed = true
      } catch {
        failed.append(job)
      }
    }
    return failed
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
    job.startedAt = Date()
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
      sessionSavedBytes += max(0, job.originalBytes - result.bytes)
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
