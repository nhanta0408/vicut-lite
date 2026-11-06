import AppKit
import SwiftUI

/// 48 pt custom title bar of the Queue window. The window hides the system title bar, so this
/// view leaves room for the traffic lights and handles window dragging itself.
struct QueueTitleBar: View {
  let doneCount: Int
  let activeCount: Int
  /// Hook for the side tab bar (History / Settings), which is not built yet.
  @Binding var isSidebarVisible: Bool
  let onHome: () -> Void

  var body: some View {
    HStack(spacing: DS.Space.s3) {
      HStack(spacing: DS.Space.s0_5) {
        Button { isSidebarVisible.toggle() } label: {
          DSIcon("sidebar.left", size: DS.Size.glyphLarge)
        }
        .buttonStyle(DSIconButtonStyle(size: .small, isActive: isSidebarVisible))
        .help("Menu")
        .accessibilityLabel("Toggle side tab bar")

        Button(action: onHome) {
          DSIcon("house", size: DS.Size.glyphLarge)
            .foregroundStyle(DS.Color.gold500)
        }
        .buttonStyle(DSIconButtonStyle(size: .small))
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

/// The gold "V" app mark, drawn so it stays crisp at title-bar size.
struct BrandMark: View {
  /// Points of the V on the 1024-unit icon canvas.
  private static let canvas: CGFloat = 1024
  /// macOS icon squircle: 212 pt corner on a 944 pt tile.
  private static let cornerRatio: CGFloat = 212 / 944
  private static let points: [CGPoint] = [
    CGPoint(x: 312, y: 334), CGPoint(x: 436, y: 334), CGPoint(x: 512, y: 494),
    CGPoint(x: 588, y: 334), CGPoint(x: 712, y: 334), CGPoint(x: 512, y: 730)
  ]

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      let scale = side / Self.canvas
      ZStack {
        RoundedRectangle(cornerRadius: side * Self.cornerRatio, style: .continuous)
          .fill(DS.Color.bgInset)
        RoundedRectangle(cornerRadius: side * Self.cornerRatio, style: .continuous)
          .strokeBorder(DS.Color.borderGold, lineWidth: DS.Stroke.hairline)
        Path { path in
          path.addLines(Self.points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) })
          path.closeSubpath()
        }
        .fill(DS.Color.gold500)
      }
      .frame(width: side, height: side)
    }
    .accessibilityHidden(true)
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
