import Foundation

/// The visible window [start, start + span] of the editor timeline.
public struct TimelineViewport: Equatable, Sendable {
  /// Deepest zoom: one second across the whole timeline width.
  public static let minSpan = 1.0
  /// When following the playhead, leave this share of the view behind it for context.
  static let revealLead = 0.1
  static let fitPadding = 0.1

  public private(set) var duration: Double
  public private(set) var start: Double = 0
  public private(set) var span: Double

  public init(duration: Double) {
    self.duration = max(duration, 0)
    span = self.duration
  }

  public var end: Double { start + span }
  public var isZoomed: Bool { span < duration - Timeline.epsilon }
  public var zoomFactor: Double { span > 0 ? duration / span : 1 }

  public mutating func setDuration(_ newDuration: Double) {
    self = TimelineViewport(duration: newDuration)
  }

  /// Zooms by `factor` (>1 = in) keeping `anchor` at the same place on screen.
  public mutating func zoom(by factor: Double, anchor: Double) {
    guard factor > 0, span > 0 else { return }
    setSpan(span / factor, anchor: anchor)
  }

  public mutating func setSpan(_ newSpan: Double, anchor: Double) {
    guard duration > 0 else { return }
    let ratio = span > 0 ? (anchor - start) / span : 0
    span = min(max(newSpan, min(Self.minSpan, duration)), duration)
    start = anchor - ratio * span
    clamp()
  }

  public mutating func pan(by seconds: Double) {
    start += seconds
    clamp()
  }

  public mutating func moveStart(to seconds: Double) {
    start = seconds
    clamp()
  }

  /// Brings `time` into view (no-op when already visible).
  public mutating func reveal(_ time: Double) {
    guard time < start || time > end else { return }
    start = time - span * Self.revealLead
    clamp()
  }

  public mutating func fit(_ range: ClosedRange<Double>) {
    let length = range.upperBound - range.lowerBound
    let padded = length * (1 + 2 * Self.fitPadding)
    span = min(max(padded, min(Self.minSpan, duration)), duration)
    start = range.lowerBound + length / 2 - span / 2
    clamp()
  }

  public mutating func reset() {
    start = 0
    span = duration
  }

  /// Position of `time` as a fraction of the visible width (may be outside 0...1).
  public func fraction(of time: Double) -> Double {
    span > 0 ? (time - start) / span : 0
  }

  public func time(atFraction fraction: Double) -> Double {
    min(max(start + fraction * span, 0), duration)
  }

  private mutating func clamp() {
    start = min(max(start, 0), max(duration - span, 0))
  }
}

public enum TimelineRuler {
  static let steps: [Double] = [0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600]

  /// Smallest "nice" step whose ticks are at least `minSpacing` points apart.
  public static func tickInterval(span: Double, width: Double, minSpacing: Double) -> Double {
    guard span > 0, width > 0 else { return steps.last ?? 1 }
    let pointsPerSecond = width / span
    return steps.first { $0 * pointsPerSecond >= minSpacing } ?? steps.last ?? 1
  }

  public static func ticks(start: Double, end: Double, interval: Double) -> [Double] {
    guard interval > 0, end >= start else { return [] }
    var tick = (start / interval).rounded(.up) * interval
    var result: [Double] = []
    while tick <= end + Timeline.epsilon {
      result.append(tick)
      tick += interval
    }
    return result
  }
}
