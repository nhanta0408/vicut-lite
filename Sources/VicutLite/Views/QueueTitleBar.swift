import AppKit
import SwiftUI

/// 48 pt custom title bar of the Queue window. The window hides the system title bar, so this
/// view leaves room for the traffic lights and handles window dragging itself.
struct QueueTitleBar: View {
  let doneCount: Int
  let activeCount: Int
  let page: QueuePage
  @Binding var isSidebarVisible: Bool
  let onHome: () -> Void

  var body: some View {
    HStack(spacing: DS.Space.s3) {
      HStack(spacing: DS.Space.s0_5) {
        Button { isSidebarVisible.toggle() } label: {
          DSIcon("sidebar.left", size: DS.Size.glyphLarge)
        }
        .buttonStyle(DSIconButtonStyle(size: .medium, isActive: isSidebarVisible))
        .help("Menu")
        .accessibilityLabel("Toggle side tab bar")
        .accessibilityValue(isSidebarVisible ? "Expanded" : "Collapsed")

        Button(action: onHome) {
          // Gold only while Home is showing, so the icon doubles as a location cue.
          DSIcon("house", size: DS.Size.glyphLarge)
            .foregroundStyle(page == .home ? DS.Color.gold500 : DS.Color.textSecondary)
        }
        .buttonStyle(DSIconButtonStyle(size: .medium))
        .help("Home")
        .accessibilityLabel("Home")
      }
      // Otherwise the first button grabs a focus ring as soon as the window opens.
      .focusEffectDisabled()

      Rectangle()
        .fill(DS.Color.borderWindow)
        .frame(width: DS.Stroke.hairline, height: DS.Size.dividerHeight)

      HStack(spacing: DS.Space.s2) {
        BrandMark()
          .frame(width: DS.Size.brandMark, height: DS.Size.brandMark)
        (Text("ViCut ").foregroundStyle(DS.Color.textPrimary) + Text("Lite").foregroundStyle(DS.Color.gold500))
          .dsText(DS.Typography.heading)
      }
      .accessibilityElement(children: .combine)

      if page != .home {
        HStack(spacing: DS.Space.s3) {
          Text("/")
            .foregroundStyle(DS.Color.textFaint)
          Text(page.title)
            .dsText(DS.Typography.bodyBold)
            .foregroundStyle(DS.Color.textPrimary)
        }
        .dsText(DS.Typography.body)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current page: \(page.title)")
      }

      Spacer(minLength: DS.Space.s3)

      Text("\(doneCount) done · \(activeCount) in progress")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .monospacedDigit()
        .lineLimit(1)
    }
    .padding(.leading, DS.Size.trafficLights)
    .padding(.trailing, DS.Space.s4)
    .frame(height: DS.Size.titleBar)
    .background(WindowDragArea())
    .background(DS.Color.bgChrome)
    .overlay(alignment: .bottom) {
      Rectangle().fill(DS.Color.borderSubtle).frame(height: DS.Stroke.hairline)
    }
  }
}

/// The app mark from `Resources/AppIcon.svg`: a gold V split along a diagonal into two
/// offset halves, on a dark squircle. Drawn as vectors so it stays crisp at 22–30 pt.
struct BrandMark: View {
  /// Every coordinate below is on the icon's 1024-unit canvas.
  nonisolated fileprivate static let canvas: CGFloat = 1024
  /// Squircle tile: 944 units wide, 40 in from each edge, 212 corner.
  private static let tileInset: CGFloat = 40
  private static let tileCorner: CGFloat = 212
  /// The V's outline is stroked this wide with round joins, which rounds its tips.
  private static let vStroke: CGFloat = 44
  private static let vPoints: [CGPoint] = [
    CGPoint(x: 312, y: 334), CGPoint(x: 436, y: 334), CGPoint(x: 512, y: 494),
    CGPoint(x: 588, y: 334), CGPoint(x: 712, y: 334), CGPoint(x: 512, y: 730)
  ]
  /// Halves of the cut: the clip region and how far that half is nudged.
  private static let halves: [(clip: [CGPoint], offset: CGSize)] = [
    ([CGPoint(x: 0, y: 0), CGPoint(x: 1024, y: 0), CGPoint(x: 1024, y: 251), CGPoint(x: 0, y: 732)],
     CGSize(width: 13, height: -3)),
    ([CGPoint(x: 0, y: 773), CGPoint(x: 1024, y: 292), CGPoint(x: 1024, y: 1024), CGPoint(x: 0, y: 1024)],
     CGSize(width: -13, height: 5))
  ]

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      let scale = side / Self.canvas
      let tile = RoundedRectangle(cornerRadius: Self.tileCorner * scale, style: .continuous)
      ZStack {
        tile
          .fill(DS.Color.bgInset)
          .overlay(tile.strokeBorder(DS.Color.borderGold, lineWidth: DS.Stroke.hairline))
          .padding(Self.tileInset * scale)
        ForEach(Self.halves.indices, id: \.self) { index in
          let half = Self.halves[index]
          let vShape = CanvasPolygon(points: Self.vPoints)
          ZStack {
            vShape.fill(DS.Color.gold500)
            vShape.stroke(DS.Color.gold500, style: StrokeStyle(lineWidth: Self.vStroke * scale, lineJoin: .round))
          }
          .clipShape(CanvasPolygon(points: half.clip))
          .offset(x: half.offset.width * scale, y: half.offset.height * scale)
        }
      }
      .frame(width: side, height: side)
    }
    .accessibilityHidden(true)
  }
}

/// Polygon given in 1024-unit icon coordinates, scaled to whatever square it is drawn in.
private struct CanvasPolygon: Shape {
  let points: [CGPoint]

  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height) / BrandMark.canvas
    var path = Path()
    path.addLines(points.map { CGPoint(x: rect.minX + $0.x * scale, y: rect.minY + $0.y * scale) })
    path.closeSubpath()
    return path
  }
}

/// Lets the custom title bar move the window (and zoom on double-click) like a native one.
private struct WindowDragArea: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { DragView() }
  func updateNSView(_ nsView: NSView, context: Context) {}

  final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
      if event.clickCount == 2 {
        window?.performZoom(nil)
      } else {
        window?.performDrag(with: event)
      }
    }
  }
}
