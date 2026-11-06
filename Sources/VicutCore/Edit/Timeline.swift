import Foundation

public enum TimelineError: Error, Equatable {
  case emptyOutput
}

public enum Timeline {
  /// Intervals shorter than this are float noise from boundary math, not user intent.
  static let epsilon = 0.001

  /// Turns user marks (painted in order; later marks win) into contiguous, non-overlapping
  /// segments covering [0, duration], with cut segments removed and equal neighbours merged.
  public static func normalize(marks: [Segment], duration: Double) throws -> [Segment] {
    let kept = resolve(marks: marks, duration: duration).filter { $0.action != .cut }
    guard !kept.isEmpty else { throw TimelineError.emptyOutput }
    return kept
  }

  /// Like `normalize` but keeps `.cut` segments, so the UI can draw the whole timeline.
  public static func resolve(marks: [Segment], duration: Double) -> [Segment] {
    let clamped = marks.compactMap { mark -> Segment? in
      let start = min(max(min(mark.start, mark.end), 0), duration)
      let end = min(max(max(mark.start, mark.end), 0), duration)
      guard end - start > epsilon else { return nil }
      let action: SegmentAction = mark.action == .speed(1) ? .keep : mark.action
      return Segment(start: start, end: end, action: action)
    }

    let boundaries = Set([0, duration] + clamped.flatMap { [$0.start, $0.end] }).sorted()
    var covering: [Segment] = []
    for (start, end) in zip(boundaries, boundaries.dropFirst()) where end - start > epsilon {
      let mid = (start + end) / 2
      let action = clamped.last { $0.start <= mid && mid <= $0.end }?.action ?? .keep
      if let last = covering.last, last.action == action, abs(last.end - start) <= epsilon {
        covering[covering.count - 1].end = end
      } else {
        covering.append(Segment(start: start, end: end, action: action))
      }
    }

    return covering
  }

  public static func outputDuration(_ segments: [Segment]) -> Double {
    segments.reduce(0) { total, segment in
      let rate = segment.action.playbackRate
      return rate > 0 ? total + segment.length / rate : total
    }
  }

  public static func isUnedited(_ segments: [Segment], duration: Double) -> Bool {
    guard segments.count == 1, let only = segments.first else { return false }
    return only.action == .keep && only.start <= epsilon && abs(only.end - duration) <= epsilon
  }

  /// Gaps under a second between marks are almost always a mouse miss, not intent.
  public static let maxSnapDistance = 1.0
  /// On-screen reach of snapping; keeps sub-second edits possible when zoomed in.
  static let snapReachPoints = 12.0

  public static func snapThreshold(visibleSpan: Double, width: Double) -> Double {
    guard width > 0 else { return maxSnapDistance }
    return min(maxSnapDistance, visibleSpan / width * snapReachPoints)
  }

  /// Clip ends plus every boundary between differently-marked parts.
  public static func snapPoints(marks: [Segment], duration: Double) -> [Double] {
    let bounds = resolve(marks: marks, duration: duration).flatMap { [$0.start, $0.end] }
    return Set([0, duration] + bounds).sorted()
  }

  public static func snap(_ time: Double, to points: [Double], within threshold: Double) -> Double? {
    points
      .filter { abs($0 - time) <= threshold }
      .min { abs($0 - time) < abs($1 - time) }
  }
}

