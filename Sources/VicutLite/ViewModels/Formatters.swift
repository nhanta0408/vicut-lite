import Foundation

enum Formatters {
  static func bytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .decimal)
  }

  static func duration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let tenths = Int((seconds * 10).rounded())
    let minutes = tenths / 600
    let secs = (tenths / 10) % 60
    return String(format: "%d:%02d.%d", minutes, secs, tenths % 10)
  }

  static func speed(_ factor: Double) -> String {
    String(format: "%g×", factor)
  }
}
