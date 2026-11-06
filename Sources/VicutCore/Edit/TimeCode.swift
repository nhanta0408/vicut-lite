import Foundation

/// Times typed into the Spans panel: `ss`, `m:ss` or `h:mm:ss`, each with optional decimals.
public enum TimeCode {
  public static func parse(_ text: String) -> Double? {
    let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
    guard (1...3).contains(parts.count), let last = parts.last, let seconds = decimal(last) else { return nil }
    var leading: [Int] = []
    for part in parts.dropLast() {
      guard !part.isEmpty, part.allSatisfy(\.isASCIIDigit), let value = Int(part) else { return nil }
      leading.append(value)
    }
    // Only the leading field may run past 59; a later one over 59 is a typo, not a carry.
    if !leading.isEmpty, seconds >= 60 { return nil }
    if leading.count == 2, leading[1] >= 60 { return nil }
    return leading.reduce(0) { $0 * 60 + Double($1) } * 60 + seconds
  }

  private static func decimal(_ text: Substring) -> Double? {
    let digits = text.filter { $0 != "." }
    guard !digits.isEmpty, digits.allSatisfy(\.isASCIIDigit), text.count - digits.count <= 1 else { return nil }
    return Double(text)
  }
}

private extension Character {
  var isASCIIDigit: Bool { isASCII && isNumber }
}

extension Timeline {
  /// Marks with `span` reverted to normal, so the same span can be repainted at new times.
  public static func releasing(_ span: Segment, marks: [Segment]) -> [Segment] {
    guard span.action != .keep else { return marks }
    return marks + [Segment(start: span.start, end: span.end, action: .keep)]
  }
}
