import AppKit
import SwiftUI
import VicutCore

/// Zoomable timeline: ruler, thumbnail track with marks/selection, and an overview bar when zoomed.
struct EditTimelineView: View {
  let model: EditorModel
  @State private var dragSnapPoints: [Double]?
  /// Selection start in seconds, fixed when the drag begins so auto-scroll can't shift it.
  @State private var dragAnchor: Double?
  @State private var pointer = PointerState()
  @State private var scrollMonitor: Any?
  @State private var pinchBase: CGFloat?

  private let trackHeight: CGFloat = 72
  private let rulerHeight: CGFloat = 18
  private let overviewHeight: CGFloat = 14
  private static let minTickSpacing = 70.0
  /// Dragging this close to an edge scrolls the zoomed view.
  private static let autoScrollEdge: CGFloat = 8
  private static let autoScrollShare = 0.03

  var body: some View {
    VStack(spacing: 4) {
      GeometryReader { geo in
        let width = geo.size.width
        VStack(spacing: 2) {
          ruler(width: width)
          track(width: width)
        }
        .onAppear { pointer.width = width }
        .onChange(of: width) { _, new in pointer.width = new }
      }
      .frame(height: rulerHeight + 2 + trackHeight)
      .onContinuousHover { phase in
        if case .active(let point) = phase {
          pointer.hoverX = point.x
        } else {
          pointer.hoverX = nil
        }
      }

      if model.viewport.isZoomed {
        GeometryReader { geo in
          overview(width: geo.size.width)
        }
        .frame(height: overviewHeight)
      }
    }
    .onAppear(perform: installScrollMonitor)
    .onDisappear(perform: removeScrollMonitor)
  }

  // MARK: Ruler

  private func ruler(width: CGFloat) -> some View {
    let viewport = model.viewport
    let interval = TimelineRuler.tickInterval(span: viewport.span, width: width, minSpacing: Self.minTickSpacing)
    let ticks = TimelineRuler.ticks(start: viewport.start, end: viewport.end, interval: interval)
    return ZStack(alignment: .topLeading) {
      ForEach(ticks, id: \.self) { tick in
        HStack(spacing: 3) {
          Rectangle().fill(Color.secondary.opacity(0.6)).frame(width: 1, height: rulerHeight)
          Text(Self.label(tick, interval: interval))
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize()
        }
        .offset(x: x(tick, width))
      }
    }
    .frame(width: width, height: rulerHeight, alignment: .topLeading)
    .clipped()
  }

  private static func label(_ seconds: Double, interval: Double) -> String {
    let minutes = Int(seconds) / 60
    let secs = seconds - Double(minutes * 60)
    if interval < 1 {
      return String(format: "%d:%04.1f", minutes, secs)
    }
    return String(format: "%d:%02d", minutes, Int(secs.rounded()))
  }

  // MARK: Track

  private func track(width: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      Rectangle().fill(Color.black.opacity(0.6))
      ForEach(Array(model.thumbnails.enumerated()), id: \.offset) { _, thumb in
        Image(decorative: thumb.image, scale: 1)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: max(x(thumb.range.upperBound, width) - x(thumb.range.lowerBound, width), 1), height: trackHeight)
          .clipped()
          .offset(x: x(thumb.range.lowerBound, width))
      }
      ForEach(model.resolved.filter { $0.action != .keep }, id: \.self) { segment in
        segmentOverlay(segment, width: width)
      }
      if let selection = model.selection {
        Rectangle()
          .fill(Color.accentColor.opacity(0.25))
          .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 2))
          .frame(width: max(x(selection.upperBound, width) - x(selection.lowerBound, width), 2), height: trackHeight)
          .offset(x: x(selection.lowerBound, width))
      }
      if let guide = model.snapGuide {
        Rectangle()
          .fill(Color.yellow)
          .frame(width: 2, height: trackHeight)
          .offset(x: x(guide, width) - 1)
      }
      Rectangle()
        .fill(Color.white)
        .shadow(radius: 1)
        .frame(width: 2, height: trackHeight)
        .offset(x: x(model.currentTime, width) - 1)
    }
    .frame(width: width, height: trackHeight, alignment: .topLeading)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .contentShape(Rectangle())
    .gesture(dragGesture(width: width))
    .simultaneousGesture(pinchGesture(width: width))
  }

  private func segmentOverlay(_ segment: Segment, width: CGFloat) -> some View {
    let isCut = segment.action == .cut
    let label: String
    if case .speed(let factor) = segment.action {
      label = Formatters.speed(factor)
    } else {
      label = "CUT"
    }
    return ZStack {
      Rectangle().fill(isCut ? Color.red.opacity(0.55) : Color.orange.opacity(0.45))
      if isCut {
        Image(systemName: "scissors").foregroundStyle(.white)
      }
      Text(label)
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color.black.opacity(0.4)))
        .offset(y: isCut ? 20 : 0)
    }
    .frame(width: max(x(segment.end, width) - x(segment.start, width), 1), height: trackHeight)
    .offset(x: x(segment.start, width))
    .allowsHitTesting(false)
  }

  // MARK: Overview (whole clip, only when zoomed)

  private func overview(width: CGFloat) -> some View {
    let duration = max(model.duration, 0.001)
    let viewport = model.viewport
    let full: (Double) -> CGFloat = { CGFloat($0 / duration) * width }
    return ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2))
      ForEach(model.resolved.filter { $0.action != .keep }, id: \.self) { segment in
        Rectangle()
          .fill(segment.action == .cut ? Color.red.opacity(0.7) : Color.orange.opacity(0.7))
          .frame(width: max(full(segment.end) - full(segment.start), 1), height: overviewHeight)
          .offset(x: full(segment.start))
      }
      Rectangle()
        .fill(Color.white)
        .frame(width: 1, height: overviewHeight)
        .offset(x: full(model.currentTime))
      RoundedRectangle(cornerRadius: 3)
        .strokeBorder(Color.accentColor, lineWidth: 2)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.15)))
        .frame(width: max(full(viewport.end) - full(viewport.start), 6), height: overviewHeight)
        .offset(x: full(viewport.start))
    }
    .frame(width: width, height: overviewHeight, alignment: .topLeading)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0).onChanged { value in
        let center = Double(value.location.x / max(width, 1)) * duration
        model.moveViewport(start: center - viewport.span / 2)
      }
    )
    .help("Drag to move around the clip")
  }

  // MARK: Gestures

  private func dragGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        if dragSnapPoints == nil {
          dragSnapPoints = model.snapPoints
          dragAnchor = snapped(time(value.startLocation.x, width), width: width, showGuide: false)
        }
        autoScroll(at: value.location.x, width: width)
        let start = dragAnchor ?? time(value.startLocation.x, width)
        let current = snapped(time(value.location.x, width), width: width, showGuide: true)
        if abs(value.translation.width) > 3 {
          model.select(from: start, to: current)
        }
        model.seek(to: current)
      }
      .onEnded { value in
        if abs(value.translation.width) <= 3 {
          model.selection = nil
          model.seek(to: time(value.location.x, width))
        }
        dragSnapPoints = nil
        dragAnchor = nil
        model.snapGuide = nil
      }
  }

  private func pinchGesture(width: CGFloat) -> some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let previous = pinchBase ?? 1
        let factor = value.magnification / previous
        pinchBase = value.magnification
        model.zoom(by: Double(factor), anchor: time(value.startLocation.x, width))
      }
      .onEnded { _ in pinchBase = nil }
  }

  /// Snaps to clip ends and mark boundaries within 1s (less when zoomed in). Hold ⌘ to place freely.
  private func snapped(_ time: Double, width: CGFloat, showGuide: Bool) -> Double {
    guard !NSEvent.modifierFlags.contains(.command), let points = dragSnapPoints else {
      if showGuide { model.snapGuide = nil }
      return time
    }
    let threshold = Timeline.snapThreshold(visibleSpan: model.viewport.span, width: Double(width))
    let target = Timeline.snap(time, to: points, within: threshold)
    if showGuide {
      model.snapGuide = target
    }
    return target ?? time
  }

  private func autoScroll(at x: CGFloat, width: CGFloat) {
    guard model.viewport.isZoomed else { return }
    let step = model.viewport.span * Self.autoScrollShare
    if x < Self.autoScrollEdge {
      model.pan(by: -step)
    } else if x > width - Self.autoScrollEdge {
      model.pan(by: step)
    }
  }

  // MARK: Scroll wheel / trackpad: scroll pans, ⌥ or ⌘ + scroll zooms

  private func installScrollMonitor() {
    guard scrollMonitor == nil else { return }
    let model = model
    let pointer = pointer
    scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
      guard let hoverX = pointer.hoverX, pointer.width > 0 else { return event }
      let width = pointer.width
      let lineScale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
      if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command) {
        let factor = exp(Double(event.scrollingDeltaY * lineScale) * 0.01)
        model.zoom(by: factor, anchor: model.viewport.time(atFraction: Double(hoverX / width)))
      } else {
        let delta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.scrollingDeltaY
        model.pan(by: -Double(delta * lineScale / width) * model.viewport.span)
      }
      return nil
    }
  }

  private func removeScrollMonitor() {
    if let scrollMonitor {
      NSEvent.removeMonitor(scrollMonitor)
    }
    scrollMonitor = nil
    pointer.hoverX = nil
  }

  // MARK: Geometry

  private func x(_ seconds: Double, _ width: CGFloat) -> CGFloat {
    CGFloat(model.viewport.fraction(of: seconds)) * width
  }

  private func time(_ x: CGFloat, _ width: CGFloat) -> Double {
    guard width > 0 else { return 0 }
    return model.viewport.time(atFraction: Double(x / width))
  }
}

/// Read by the AppKit scroll-wheel monitor; a reference so the escaping closure sees live values.
@MainActor
private final class PointerState {
  var hoverX: CGFloat?
  var width: CGFloat = 0
}
