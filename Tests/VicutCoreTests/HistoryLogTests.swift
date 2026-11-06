import Foundation
import Testing
@testable import VicutCore

struct HistoryLogTests {
  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }()

  /// 2026-11-06 15:00 UTC.
  private static let now = Date(timeIntervalSince1970: 1_793_977_200)
  private static let hour: TimeInterval = 3600
  private static let day: TimeInterval = 86400

  private static func entry(_ name: String, ago: TimeInterval, original: Int64 = 100, output: Int64 = 10) -> HistoryEntry {
    HistoryEntry(
      output: URL(fileURLWithPath: "/tmp/\(name).mp4"),
      originalBytes: original,
      outputBytes: output,
      date: now.addingTimeInterval(-ago)
    )
  }

  // MARK: Grouping

  @Test func groupsByCalendarDay() {
    let cal = Self.calendar
    let now = Self.now
    #expect(HistoryGroup.of(now, now: now, calendar: cal) == .today)
    // 00:30 today is still today even though it's 14.5 hours ago.
    #expect(HistoryGroup.of(now.addingTimeInterval(-14.5 * Self.hour), now: now, calendar: cal) == .today)
    // 23:00 yesterday is less than a day ago but a different calendar day.
    #expect(HistoryGroup.of(now.addingTimeInterval(-16 * Self.hour), now: now, calendar: cal) == .yesterday)
    #expect(HistoryGroup.of(now.addingTimeInterval(-3 * Self.day), now: now, calendar: cal) == .previousWeek)
    #expect(HistoryGroup.of(now.addingTimeInterval(-7 * Self.day), now: now, calendar: cal) == .previousWeek)
    #expect(HistoryGroup.of(now.addingTimeInterval(-8 * Self.day), now: now, calendar: cal) == .older)
  }

  @Test func futureDatesCountAsToday() {
    let future = Self.now.addingTimeInterval(Self.day)
    #expect(HistoryGroup.of(future, now: Self.now, calendar: Self.calendar) == .today)
  }

  @Test func sectionsAreOrderedAndSkipEmptyGroups() {
    let log = HistoryLog(entries: [
      Self.entry("old", ago: 30 * Self.day),
      Self.entry("today-early", ago: 5 * Self.hour),
      Self.entry("today-late", ago: Self.hour),
      Self.entry("week", ago: 4 * Self.day)
    ])

    let sections = log.sections(now: Self.now, calendar: Self.calendar)

    #expect(sections.map(\.group) == [.today, .previousWeek, .older])
    #expect(sections.first?.entries.map(\.outputName) == ["today-late.mp4", "today-early.mp4"])
  }

  // MARK: Saved %

  @Test func savedPercentRoundsReduction() {
    #expect(Self.entry("a", ago: 0, original: 30_400_000, output: 611_000).savedPercent == 98)
    #expect(Self.entry("b", ago: 0, original: 1000, output: 1000).savedPercent == 0)
  }

  @Test func savedPercentIsNegativeWhenOutputGrew() {
    #expect(Self.entry("a", ago: 0, original: 100, output: 120).savedPercent == -20)
  }

  @Test func savedPercentIsNilWithoutOriginalSize() {
    #expect(Self.entry("a", ago: 0, original: 0, output: 50).savedPercent == nil)
  }

  // MARK: Mutations

  @Test func recordPutsNewestFirstAndReplacesSamePath() {
    var log = HistoryLog()
    let first = Self.entry("clip", ago: Self.day)
    let other = Self.entry("other", ago: Self.hour)
    let again = Self.entry("clip", ago: 0)

    log.record(first)
    log.record(other)
    log.record(again)

    #expect(log.entries.map(\.id) == [again.id, other.id])
  }

  @Test func recordCapsEntryCount() {
    var log = HistoryLog()
    for index in 0...HistoryLog.maxEntries {
      log.record(Self.entry("clip-\(index)", ago: 0))
    }
    #expect(log.entries.count == HistoryLog.maxEntries)
    #expect(log.entries.first?.outputName == "clip-\(HistoryLog.maxEntries).mp4")
  }

  @Test func removeAndClear() {
    let keep = Self.entry("keep", ago: 0)
    let drop = Self.entry("drop", ago: Self.hour)
    var log = HistoryLog(entries: [keep, drop])

    log.remove(id: drop.id)
    #expect(log.entries == [keep])

    log.clear()
    #expect(log.entries.isEmpty)
  }

  @Test func missingIDsReportsFilesThatAreGone() {
    let present = Self.entry("present", ago: 0)
    let gone = Self.entry("gone", ago: 0)
    let log = HistoryLog(entries: [present, gone])

    let missing = log.missingIDs { $0 == present.output }

    #expect(missing == [gone.id])
  }

  @Test func missingIDsUsesRealFileSystem() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let existing = dir.appendingPathComponent("here.mp4")
    FileManager.default.createFile(atPath: existing.path, contents: Data())
    let found = HistoryEntry(output: existing, originalBytes: 1, outputBytes: 1)
    let lost = HistoryEntry(output: dir.appendingPathComponent("moved.mp4"), originalBytes: 1, outputBytes: 1)

    let missing = HistoryLog(entries: [found, lost]).missingIDs { FileManager.default.fileExists(atPath: $0.path) }

    #expect(missing == [lost.id])
  }

  // MARK: Persistence

  @Test func persistenceRoundTrip() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = HistoryFile(url: dir.appendingPathComponent("nested/history.json"))
    let log = HistoryLog(entries: [Self.entry("a", ago: 0), Self.entry("b", ago: Self.day)])

    try file.save(log)
    let loaded = try file.load()

    #expect(loaded == log)
  }

  @Test func loadingMissingFileGivesEmptyLog() throws {
    let file = HistoryFile(url: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json"))
    #expect(try file.load().entries.isEmpty)
  }

  @Test func loadingCorruptFileThrows() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
    try Data("not json".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: (any Error).self) { try HistoryFile(url: url).load() }
  }
}
