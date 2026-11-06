import Foundation
import VicutCore

/// Strings shown on the Home (Queue) screen.
enum QueueFormat {
  static let secondsPerMinute = 60.0

  /// "−98%"; nil when the output is not smaller.
  static func savedPercent(original: Int64, output: Int64) -> String? {
    guard original > 0, output < original else { return nil }
    let saved = 100 - Int((Double(output) / Double(original) * 100).rounded())
    return "−\(saved)%"
  }

  /// Linear extrapolation of elapsed time; good enough for single-pass progress.
  static func remaining(startedAt: Date?, fraction: Double, now: Date = Date()) -> String? {
    guard let startedAt, fraction > 0, fraction < 1 else { return nil }
    let elapsed = now.timeIntervalSince(startedAt)
    let left = elapsed / fraction * (1 - fraction)
    guard left.isFinite, left >= 0 else { return nil }
    if left < secondsPerMinute {
      return "~\(max(1, Int(left.rounded())))s left"
    }
    return "~\(Int((left / secondsPerMinute).rounded()))m left"
  }

  /// "2:18" for the thumbnail chip.
  static func clipDuration(_ seconds: Double) -> String? {
    guard seconds.isFinite, seconds > 0 else { return nil }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / Int(secondsPerMinute), total % Int(secondsPerMinute))
  }

  /// Name the encoder will write, before the unique "-2" suffix is known.
  @MainActor
  static func expectedOutputName(for job: Job) -> String {
    if let result = job.result {
      return result.output.lastPathComponent
    }
    return job.input.deletingPathExtension().lastPathComponent + job.settings.outputSuffix + ".mp4"
  }

  static func target(_ settings: CompressSettings) -> String {
    settings.targetBytes.map { Formatters.bytes($0) } ?? "No limit"
  }

  static func resolution(_ settings: CompressSettings) -> String {
    settings.maxDimension.map { "≤\($0)px" } ?? "Original"
  }

  static func fps(_ settings: CompressSettings) -> String {
    "\(settings.fpsCap) fps"
  }

  static func videoCount(_ count: Int) -> String {
    count == 1 ? "1 video" : "\(count) videos"
  }
}
