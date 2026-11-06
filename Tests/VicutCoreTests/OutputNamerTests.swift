import Foundation
import Testing
@testable import VicutCore

struct OutputNamerTests {
  @Test func appendsSuffixAndAvoidsCollisions() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let input = dir.appendingPathComponent("Screen Recording 2026.mov")

    let first = OutputNamer.uniqueOutput(for: input, suffix: "-vicut")
    #expect(first.lastPathComponent == "Screen Recording 2026-vicut.mp4")
    FileManager.default.createFile(atPath: first.path, contents: Data())

    let second = OutputNamer.uniqueOutput(for: input, suffix: "-vicut")
    #expect(second.lastPathComponent == "Screen Recording 2026-vicut-2.mp4")
  }
}
