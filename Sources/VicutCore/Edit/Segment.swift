import Foundation

public enum SegmentAction: Equatable, Hashable, Sendable, Codable {
  case keep
  case cut
  case speed(Double)

  /// Factor the segment's duration is divided by in the output; 0 for cut.
  var playbackRate: Double {
    switch self {
    case .keep: 1
    case .cut: 0
    case .speed(let factor): factor
    }
  }
}

public struct Segment: Equatable, Hashable, Sendable, Codable {
  public var start: Double
  public var end: Double
  public var action: SegmentAction

  public init(start: Double, end: Double, action: SegmentAction) {
    self.start = start
    self.end = end
    self.action = action
  }

  public var length: Double { end - start }
}
