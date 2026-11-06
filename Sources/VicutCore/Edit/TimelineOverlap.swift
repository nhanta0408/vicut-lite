import Foundation

/// What painting a range with an action would do to the cut / speed parts already there.
public struct OverlapImpact: Equatable, Sendable {
  /// Edited parts that lie completely inside the range and would disappear.
  public let covered: [Segment]
  /// Edited parts that would only lose the overlapping piece.
  public let trimmed: [Segment]

  public var isEmpty: Bool { covered.isEmpty && trimmed.isEmpty }
}

extension Timeline {
  /// Normal parts and parts with the same action are left out: replacing them loses nothing.
  public static func overlap(
    of range: ClosedRange<Double>,
    action: SegmentAction,
    marks: [Segment],
    duration: Double
  ) -> OverlapImpact {
    var covered: [Segment] = []
    var trimmed: [Segment] = []
    for segment in resolve(marks: marks, duration: duration) where segment.action != .keep && segment.action != action {
      let overlapsRange = segment.end > range.lowerBound + epsilon && segment.start < range.upperBound - epsilon
      guard overlapsRange else { continue }
      if segment.start >= range.lowerBound - epsilon && segment.end <= range.upperBound + epsilon {
        covered.append(segment)
      } else {
        trimmed.append(segment)
      }
    }
    return OverlapImpact(covered: covered, trimmed: trimmed)
  }

  /// The resolved part under `time`; the clip end belongs to the last part.
  public static func span(at time: Double, marks: [Segment], duration: Double) -> Segment? {
    let spans = resolve(marks: marks, duration: duration)
    return spans.first { $0.start <= time && time < $0.end } ?? spans.last.flatMap { time >= $0.end - epsilon ? $0 : nil }
  }
}
