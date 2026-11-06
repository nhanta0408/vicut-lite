import Foundation
import Observation
import os
import VicutCore

/// Past exports, persisted as JSON in Application Support. Logic lives in `HistoryLog` (VicutCore) so it is unit-tested.
@MainActor
@Observable
final class HistoryStore {
  private(set) var log: HistoryLog
  /// Cached so views don't hit the file system on every redraw; refreshed by `refreshAvailability()`.
  private(set) var missingIDs: Set<UUID> = []

  @ObservationIgnored private let file: HistoryFile?
  @ObservationIgnored private let fileExists: (URL) -> Bool
  @ObservationIgnored private let logger = Logger(subsystem: "VicutLite", category: "History")

  init(
    file: HistoryFile? = try? HistoryFile.standard(),
    fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
  ) {
    self.file = file
    self.fileExists = fileExists
    do {
      log = try file?.load() ?? HistoryLog()
    } catch {
      logger.error("History file unreadable, starting empty: \(error.localizedDescription)")
      log = HistoryLog()
    }
    refreshAvailability()
  }

  var entries: [HistoryEntry] { log.entries }
  var missingCount: Int { missingIDs.count }

  func isFound(_ entry: HistoryEntry) -> Bool {
    !missingIDs.contains(entry.id)
  }

  func sections(now: Date = Date(), calendar: Calendar = .current) -> [HistorySection] {
    log.sections(now: now, calendar: calendar)
  }

  func record(output: URL, originalBytes: Int64, outputBytes: Int64) {
    log.record(HistoryEntry(output: output, originalBytes: originalBytes, outputBytes: outputBytes))
    refreshAvailability()
    persist()
  }

  func remove(_ entry: HistoryEntry) {
    log.remove(id: entry.id)
    missingIDs.remove(entry.id)
    persist()
  }

  func clear() {
    log.clear()
    missingIDs.removeAll()
    persist()
  }

  /// Files can be moved or deleted in Finder at any time, so re-check when the page shows or the app regains focus.
  func refreshAvailability() {
    let missing = log.missingIDs(fileExists: fileExists)
    if missing != missingIDs {
      missingIDs = missing
    }
  }

  private func persist() {
    guard let file else { return }
    do {
      try file.save(log)
    } catch {
      logger.error("Failed to save history: \(error.localizedDescription)")
    }
  }
}
