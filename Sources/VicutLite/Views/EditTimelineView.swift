import AppKit
import SwiftUI
import VicutCore

/// Zoomable span track (normal filmstrip / cut hatch / speed fill), ruler, and an overview bar when zoomed.
struct EditTimelineView: View {
  let model: EditorModel
  @State private var dragSnapPoints: [Double]?
  /// Selection start in seconds, fixed when the drag begins so auto-scroll can't shift it.
  @State private var dragAnchor: Double?
  @State private var pointer = PointerState()
  @State private var scrollMonitor: Any?
  @State private var pinchBase: CGFloat?

  private static let minTickSpacing = 70.0
  /// Dragging this close to an edge scrolls the zoomed view.
  private static let autoScrollEdge: CGFloat = 8
  private static let autoScrollShare = 0.03
  /// A press that moves less than this is a click (select span + seek), not a range drag.
  private static let clickSlop: CGFloat = 3
  /// Tags are hidden on blocks narrower than this so they don't spill over neighbours.
  private static let minTagWidth: CGFloat = 24
  private static let tagTracking: CGFloat = 0.6
  /// Spans this far past the visible edges are still laid out so rings and corners clip cleanly.
  private static let offscreenMargin: CGFloat = 12
  private static let selectionFillOpacity = 0.2
  /// Keeps the overview math finite before the clip's duration has loaded.
  private static let minOverviewDuration = 0.001

  var body: some View {
    VStack(spacing: DS.Space.s1_5) {
      GeometryReader { geo in
        let width = geo.size.width
        track(width: width)
          .onAppear { pointer.width = width }
          .onChange(of: width) { _, new in pointer.width = new }
      }
      .frame(height: DS.Size.timelineTrack)
      .onContinuousHover { phase in
        if case .active(let point) = phase {
          pointer.hoverX = point.x
        } else {
          pointer.hoverX = nil
        }
      }

      GeometryReader { geo in
        ruler(width: geo.size.width)
      }
      .frame(height: DS.Size.timelineRuler)

      if model.viewport.isZoomed {
        GeometryReader { geo in
          overview(width: geo.size.width)
        }
        .frame(height: DS.Size.timelineOverview)
      }
    }
    .onAppear(perform: installScrollMonitor)
    .onDisappear(perform: removeScrollMonitor)
  }

  // MARK: Track

  private func track(width: CGFloat) -> some View {
    let spans = model.resolved
    let height = DS.Size.timelineTrack
    return ZStack(alignment: .topLeading) {
      spanFills(spans, width: width, height: height)
        .frame(width: width, height: height)
        .clipped()

      if let span = model.selection == nil ? model.selectedSpan : nil, let frame = blockFrame(span, width: width) {
        // The glow may spill above / below the track but not past its sides, so a span running
        // off-screen doesn't paint into the window padding.
        let glow = DS.Size.selectionGlow
        ZStack(alignment: .topLeading) {
          selectionRing(width: frame.width, height: height)
            .offset(x: frame.minX + glow, y: glow)
        }
        .frame(width: width + glow * 2, height: height + glow * 2, alignment: .topLeading)
        .clipped()
        .offset(x: -glow, y: -glow)
        .allowsHitTesting(false)
      }

      if let selection = model.selection, let frame = rangeFrame(selection, width: width) {
        RoundedRectangle(cornerRadius: DS.Radius.span)
          .fill(DS.Color.gold500.opacity(Self.selectionFillOpacity))
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.span)
              .strokeBorder(DS.Color.gold500, lineWidth: DS.Size.selectionRing)
          )
          .frame(width: max(frame.width, DS.Size.selectionRing * 2), height: height)
          .offset(x: frame.minX)
          .allowsHitTesting(false)
      }

      if let guide = model.snapGuide, (0...width).contains(x(guide, width)) {
        Rectangle()
          .fill(DS.Color.gold300)
          .frame(width: DS.Size.snapGuideWidth, height: height)
          .offset(x: x(guide, width) - DS.Size.snapGuideWidth / 2)
          .allowsHitTesting(false)
      }

      playhead(width: width, height: height)
    }
    .frame(width: width, height: height, alignment: .topLeading)
    .contentShape(Rectangle())
    .gesture(dragGesture(width: width))
    .simultaneousGesture(pinchGesture(width: width))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Timeline")
    .accessibilityValue(accessibilitySummary(spans))
    .help("Click a span to select it · drag to select a range (snaps to edges, ⌘ = no snap)")
  }

  /// Filmstrip + thumbnails under every span, masked to the span blocks; cut / speed fills on top.
  @ViewBuilder
  private func spanFills(_ spans: [Segment], width: CGFloat, height: CGFloat) -> some View {
    let blocks = spans.compactMap { span in blockFrame(span, width: width).map { (span, $0) } }
    ZStack(alignment: .topLeading) {
      ZStack(alignment: .topLeading) {
        Rectangle().fill(DS.Color.spanFilmFrame)
        EditorKit.StripePattern(bar: DS.Size.filmFrame, gap: DS.Size.filmGap)
          .fill(DS.Color.spanFilmGap)
        ForEach(Array(model.thumbnails.enumerated()), id: \.offset) { _, thumb in
          Image(decorative: thumb.image, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: max(x(thumb.range.upperBound, width) - x(thumb.range.lowerBound, width), 1), height: height)
            .clipped()
            .offset(x: x(thumb.range.lowerBound, width))
        }
        .opacity(DS.Color.spanThumbOpacity)
      }
      .mask(alignment: .topLeading) {
        ZStack(alignment: .topLeading) {
          ForEach(blocks, id: \.0) { _, frame in
            RoundedRectangle(cornerRadius: DS.Radius.span)
              .frame(width: frame.width, height: height)
              .offset(x: frame.minX)
          }
        }
        .frame(width: width, height: height, alignment: .topLeading)
      }

      ForEach(blocks, id: \.0) { span, frame in
        spanBlock(span, width: frame.width, height: height)
          .offset(x: frame.minX)
      }
    }
  }

  @ViewBuilder
  private func spanBlock(_ span: Segment, width: CGFloat, height: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.span)
    ZStack {
      switch span.action {
      case .keep:
        Color.clear
      case .cut:
        shape.fill(DS.Color.spanCutBase)
        EditorKit.HatchPattern(stripe: DS.Size.hatchStripe, gap: DS.Size.hatchGap)
          .fill(DS.Color.spanCutStripe)
          .clipShape(shape)
      case .speed:
        shape.fill(DS.Color.spanSpeedFill)
      }
      if let tag = span.action.tag, width >= Self.minTagWidth {
        Text(tag)
          .dsText(DS.Typography.micro)
          .tracking(Self.tagTracking)
          .foregroundStyle(span.action == .cut ? DS.Color.spanCutLabel : DS.Color.gold300)
          .lineLimit(1)
      }
    }
    .frame(width: width, height: height)
    .allowsHitTesting(false)
  }

  private func selectionRing(width: CGFloat, height: CGFloat) -> some View {
    let ring = DS.Size.selectionRing
    let glow = DS.Size.selectionGlow
    return ZStack {
      RoundedRectangle(cornerRadius: DS.Radius.span + glow)
        .strokeBorder(DS.Color.goldGlow, lineWidth: glow - ring)
        .padding(-glow)
      RoundedRectangle(cornerRadius: DS.Radius.span + ring)
        .strokeBorder(DS.Color.gold300, lineWidth: ring)
        .padding(-ring)
    }
    .frame(width: width, height: height)
  }

  private func playhead(width: CGFloat, height: CGFloat) -> some View {
    let px = x(model.currentTime, width)
    let overhang = DS.Size.playheadOverhang
    let head = DS.Size.playheadHead
    let line = DS.Size.playheadWidth
    return ZStack(alignment: .top) {
      Rectangle()
        .fill(DS.Color.playhead)
        .frame(width: line, height: height + overhang * 2)
      RoundedRectangle(cornerRadius: DS.Radius.xs)
        .fill(DS.Color.playhead)
        .frame(width: head, height: head)
    }
    .frame(width: head, height: height + overhang * 2, alignment: .top)
    .offset(x: px - head / 2, y: -overhang)
    .opacity((0...width).contains(px) ? 1 : 0)
    .allowsHitTesting(false)
  }

  // MARK: Ruler (labels under the track)

  private func ruler(width: CGFloat) -> some View {
    let viewport = model.viewport
    let interval = TimelineRuler.tickInterval(span: viewport.span, width: width, minSpacing: Self.minTickSpacing)
    let ticks = TimelineRuler.ticks(start: viewport.start, end: viewport.end, interval: interval)
    let inset = Self.minTickSpacing / 4
    return ZStack(alignment: .topLeading) {
      ForEach(ticks, id: \.self) { tick in
        Text(Self.label(tick, interval: interval))
          .dsText(DS.Typography.microRegular)
          .foregroundStyle(DS.Color.textFaint)
          .monospacedDigit()
          .fixedSize()
          .position(x: min(max(x(tick, width), inset), width - inset), y: DS.Size.timelineRuler / 2)
      }
    }
    .frame(width: width, height: DS.Size.timelineRuler, alignment: .topLeading)
    .clipped()
    .accessibilityHidden(true)
  }

  private static func label(_ seconds: Double, interval: Double) -> String {
    let minutes = Int(seconds) / 60
    let secs = seconds - Double(minutes * 60)
    if interval < 1 {
      return String(format: "%d:%04.1f", minutes, secs)
    }
    return String(format: "%d:%02d", minutes, Int(secs.rounded()))
  }

  // MARK: Overview (whole clip, only when zoomed)

  private func overview(width: CGFloat) -> some View {
    let duration = max(model.duration, Self.minOverviewDuration)
    let viewport = model.viewport
    let height = DS.Size.timelineOverview
    let full: (Double) -> CGFloat = { CGFloat($0 / duration) * width }
    return ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: DS.Radius.xs)
        .fill(DS.Color.bgApp)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xs).strokeBorder(DS.Color.borderDefault, lineWidth: DS.Size.hairline))
      ForEach(model.resolved.filter { $0.action != .keep }, id: \.self) { segment in
        Rectangle()
          .fill(segment.action.swatch)
          .frame(width: max(full(segment.end) - full(segment.start), 1), height: height)
          .offset(x: full(segment.start))
      }
      Rectangle()
        .fill(DS.Color.playhead)
        .frame(width: DS.Size.hairline, height: height)
        .offset(x: full(model.currentTime))
      RoundedRectangle(cornerRadius: DS.Radius.xs)
        .fill(DS.Color.goldTint)
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xs).strokeBorder(DS.Color.gold500, lineWidth: DS.Size.selectionRing))
        .frame(width: max(full(viewport.end) - full(viewport.start), DS.Size.swatch), height: height)
        .offset(x: full(viewport.start))
    }
    .frame(width: width, height: height, alignment: .topLeading)
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
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
        if abs(value.translation.width) > Self.clickSlop {
          model.select(from: start, to: current)
        }
        model.seek(to: current)
      }
      .onEnded { value in
        if abs(value.translation.width) <= Self.clickSlop {
          let clicked = time(value.location.x, width)
          model.selectSpan(at: clicked)
          model.seek(to: clicked)
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

  /// On-screen frame of a span block (with gutters), clamped just past the visible edges.
  private func blockFrame(_ span: Segment, width: CGFloat) -> CGRect? {
    let gutter = DS.Size.spanGutter
    return clampedFrame(from: x(span.start, width) + gutter, to: x(span.end, width) - gutter, width: width)
  }

  private func rangeFrame(_ range: ClosedRange<Double>, width: CGFloat) -> CGRect? {
    clampedFrame(from: x(range.lowerBound, width), to: x(range.upperBound, width), width: width, margin: 0)
  }

  private func clampedFrame(
    from minX: CGFloat,
    to maxX: CGFloat,
    width: CGFloat,
    margin: CGFloat = Self.offscreenMargin
  ) -> CGRect? {
    let lower = max(minX, -margin)
    let upper = min(max(maxX, minX + DS.Size.hairline), width + margin)
    guard upper > lower else { return nil }
    return CGRect(x: lower, y: 0, width: upper - lower, height: DS.Size.timelineTrack)
  }

  private func accessibilitySummary(_ spans: [Segment]) -> String {
    spans.filter { $0.action != .keep }
      .map { "\($0.action.title) \(EditorModel.rangeText($0.start...$0.end))" }
      .joined(separator: ", ")
  }
}

/// Read by the AppKit scroll-wheel monitor; a reference so the escaping closure sees live values.
@MainActor
private final class PointerState {
  var hoverX: CGFloat?
  var width: CGFloat = 0
}
