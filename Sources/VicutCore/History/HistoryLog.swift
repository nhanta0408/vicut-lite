import Foundation

/// One finished export. A snapshot: later moves or deletes of the file don't change it.
public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let output: URL
  public let originalBytes: Int64
  public let outputBytes: Int64
  public let date: Date

  public init(id: UUID = UUID(), output: URL, originalBytes: Int64, outputBytes: Int64, date: Date = Date()) {
    self.id = id
    self.output = output
    self.originalBytes = originalBytes
    self.outputBytes = outputBytes
    self.date = date
  }

  public var outputName: String { output.lastPathComponent }

  /// Whole-percent size reduction; negative when the export grew. Nil when the original size is unknown.
  public var savedPercent: Int? {
    guard originalBytes > 0 else { return nil }
    let ratio = Double(outputBytes) / Double(originalBytes)
    return Int(((1 - ratio) * 100).rounded())
  }
}

public enum HistoryGroup: String, CaseIterable, Sendable {
  case today
  case yesterday
  case previousWeek
  case older

  public var title: String {
    switch self {
    case .today: "Today"
    case .yesterday: "Yesterday"
    case .previousWeek: "Previous 7 days"
    case .older: "Older"
    }
  }

  /// Days before today that still count as "Previous 7 days" (yesterday is split out first).
  public static let previousWeekDays = 7

  public static func of(_ date: Date, now: Date, calendar: Calendar) -> HistoryGroup {
    let startOfToday = calendar.startOfDay(for: now)
    // Entries stamped in the future (clock changes) stay visible at the top instead of sinking into "Older".
    if date >= startOfToday { return .today }
    guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
          let startOfWeek = calendar.date(byAdding: .day, value: -previousWeekDays, to: startOfToday)
    else { return .older }
    if date >= startOfYesterday { return .yesterday }
    if date >= startOfWeek { return .previousWeek }
    return .older
  }
}

public struct HistorySection: Equatable, Identifiable, Sendable {
  public let group: HistoryGroup
  public let entries: [HistoryEntry]
  public var id: HistoryGroup { group }
}

/// The history list, newest first. A plain value so it can be tested without disk or UI.
public struct HistoryLog: Equatable, Sendable {
  /// Keeps the JSON file small; the oldest entries fall off.
  public static let maxEntries = 500

  public private(set) var entries: [HistoryEntry]

  public init(entries: [HistoryEntry] = []) {
    self.entries = Array(entries.sorted { $0.date > $1.date }.prefix(Self.maxEntries))
  }

  public mutating func record(_ entry: HistoryEntry) {
    // OutputNamer reuses a name once the old file is gone, so an old entry would point at the new file.
    entries.removeAll { $0.output.standardizedFileURL == entry.output.standardizedFileURL }
    entries.insert(entry, at: 0)
    if entries.count > Self.maxEntries {
      entries.removeLast(entries.count - Self.maxEntries)
    }
  }

  public mutating func remove(id: UUID) {
    entries.removeAll { $0.id == id }
  }

  public mutating func clear() {
    entries.removeAll()
  }

  public func missingIDs(fileExists: (URL) -> Bool) -> Set<UUID> {
    Set(entries.filter { !fileExists($0.output) }.map(\.id))
  }

  /// Non-empty groups in display order, entries newest first.
  public func sections(now: Date, calendar: Calendar) -> [HistorySection] {
    let grouped = Dictionary(grouping: entries) { HistoryGroup.of($0.date, now: now, calendar: calendar) }
    return HistoryGroup.allCases.compactMap { group in
      guard let items = grouped[group], !items.isEmpty else { return nil }
      return HistorySection(group: group, entries: items.sorted { $0.date > $1.date })
    }
  }
}

/// JSON persistence for `HistoryLog`.
public struct HistoryFile: Sendable {
  public let url: URL

  public init(url: URL) {
    self.url = url
  }

  /// `~/Library/Application Support/ViCut Lite/history.json`.
  public static func standard() throws -> HistoryFile {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    let directory = support.appendingPathComponent("ViCut Lite", isDirectory: true)
    return HistoryFile(url: directory.appendingPathComponent("history.json"))
  }

  /// A missing file means a fresh install, not an error.
  public func load() throws -> HistoryLog {
    guard FileManager.default.fileExists(atPath: url.path) else { return HistoryLog() }
    let data = try Data(contentsOf: url)
    return HistoryLog(entries: try JSONDecoder().decode([HistoryEntry].self, from: data))
  }

  public func save(_ log: HistoryLog) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(log.entries).write(to: url, options: .atomic)
  }
}
