import Foundation

/// Reads ffmpeg `-progress pipe:1` key=value lines and turns them into a 0...1 fraction.
public struct ProgressParser: Sendable {
  public let totalDuration: Double

  public init(totalDuration: Double) {
    self.totalDuration = totalDuration
  }

  public mutating func consume(line: String) -> Double? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed == "progress=end" {
      return 1
    }
    guard trimmed.hasPrefix("out_time_us="),
          let micros = Double(trimmed.dropFirst("out_time_us=".count))
    else {
      return nil
    }
    guard totalDuration > 0 else { return 0 }
    return min(max(micros / 1_000_000 / totalDuration, 0), 1)
  }
}
