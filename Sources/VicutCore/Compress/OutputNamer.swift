import Foundation

public enum OutputNamer {
  public static func uniqueOutput(for input: URL, suffix: String, fileManager: FileManager = .default) -> URL {
    let directory = input.deletingLastPathComponent()
    let base = input.deletingPathExtension().lastPathComponent + suffix
    var candidate = directory.appendingPathComponent(base).appendingPathExtension("mp4")
    var index = 2
    while fileManager.fileExists(atPath: candidate.path) {
      candidate = directory.appendingPathComponent("\(base)-\(index)").appendingPathExtension("mp4")
      index += 1
    }
    return candidate
  }
}
