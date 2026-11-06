import CoreGraphics

/// Where the floating drop zone sits: bottom-right of the screen the pointer is on, in AppKit's
/// global coordinates (origin bottom-left, y up).
public enum DropZonePlacement {
  /// The screen containing `point`; falls back to the first screen because the pointer can sit
  /// exactly on an outer edge, which `contains` excludes.
  public static func screenIndex(containing point: CGPoint, screens: [CGRect]) -> Int? {
    if let index = screens.firstIndex(where: { $0.contains(point) }) { return index }
    return screens.isEmpty ? nil : 0
  }

  /// Bottom-right corner of `visibleFrame`, inset by `margin`. Shrinks to fit tiny screens.
  public static func frame(size: CGSize, in visibleFrame: CGRect, margin: CGFloat) -> CGRect {
    let width = min(size.width, max(0, visibleFrame.width - 2 * margin))
    let height = min(size.height, max(0, visibleFrame.height - 2 * margin))
    return CGRect(
      x: visibleFrame.maxX - margin - width,
      y: visibleFrame.minY + margin,
      width: width,
      height: height
    )
  }

  /// Start (show) / end (hide) frame of the slide animation: pushed toward the right edge.
  public static func slidFrame(_ frame: CGRect, by distance: CGFloat) -> CGRect {
    frame.offsetBy(dx: distance, dy: 0)
  }
}
