import Foundation

/// Decides whether a system-wide mouse drag is a new file drag carrying videos.
///
/// The drag pasteboard's change count only moves when some app starts a drag, so comparing it
/// is a cheap per-event check; the file URLs are read only when it moves.
public struct DragSessionDetector: Sendable {
  public private(set) var seenChangeCount: Int

  /// Seed with the current change count so a drag that happened before launch isn't replayed.
  public init(changeCount: Int) {
    seenChangeCount = changeCount
  }

  /// - Parameter readFileURLs: the file URLs on the drag pasteboard, or nil while it is still empty.
  ///   The source app may bump the count before it has written its items, so an empty pasteboard is
  ///   not marked as seen and gets another look on the next drag event.
  /// - Returns: the supported videos of a drag not evaluated before; nil for an already-seen drag
  ///   or one without videos.
  public mutating func videosForNewDrag(changeCount: Int, readFileURLs: () -> [URL]?) -> [URL]? {
    guard changeCount != seenChangeCount else { return nil }
    guard let urls = readFileURLs() else { return nil }
    seenChangeCount = changeCount
    let videos = VideoFiles.supported(in: urls)
    return videos.isEmpty ? nil : videos
  }
}
