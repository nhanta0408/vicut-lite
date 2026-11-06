import AppKit
import SwiftUI

/// Pages the Queue window can show in place of the queue.
enum QueuePage: Hashable, CaseIterable {
  case home
  case history
  case settings

  var title: String {
    switch self {
    case .home: "Home"
    case .history: "History"
    case .settings: "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .home: "house"
    case .history: "clock.arrow.circlepath"
    case .settings: "slider.horizontal.3"
    }
  }
}

/// Side tab bar over a scrim, below the title bar (canvas: Queue `tb` state).
/// The host owns visibility and the scrim; this view only reports the chosen page.
struct SideTabBar: View {
  let current: QueuePage
  let onSelect: (QueuePage) -> Void

  var body: some View {
    VStack(spacing: DS.Space.s1) {
      ForEach(QueuePage.allCases, id: \.self) { page in
        Button { onSelect(page) } label: {
          Label(page.title, systemImage: page.systemImage)
        }
        .buttonStyle(SideTabItemButtonStyle(isCurrent: page == current))
        .accessibilityAddTraits(page == current ? .isSelected : [])
      }
      Spacer(minLength: 0)
      SideTabCredit()
    }
    .padding(.vertical, DS.Space.s3)
    .padding(.horizontal, DS.Space.s2_5)
    .frame(width: DS.Size.sideTabBarWidth)
    .frame(maxHeight: .infinity)
    .background(DS.Color.bgChrome)
    .overlay(alignment: .trailing) {
      Rectangle().fill(DS.Color.borderDefault).frame(width: DS.Stroke.hairline)
    }
    .shadow(color: DS.Color.shadowDeep, radius: DS.Shadow.panelRadius, x: DS.Shadow.panelX)
    .focusEffectDisabled()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Main")
  }
}

/// Full-width 40 pt nav row; the current page is gold-tinted with a gold.300 label.
private struct SideTabItemButtonStyle: ButtonStyle {
  let isCurrent: Bool

  func makeBody(configuration: Configuration) -> some View {
    ItemBody(configuration: configuration, isCurrent: isCurrent)
  }

  private struct ItemBody: View {
    let configuration: ButtonStyleConfiguration
    let isCurrent: Bool
    @State private var hovered = false

    var body: some View {
      let shape = RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
      configuration.label
        .labelStyle(SideTabLabelStyle())
        .dsText(DS.Typography.bodyBold)
        .foregroundStyle(isCurrent || hovered ? DS.Color.gold300 : DS.Color.textPrimary)
        .padding(.horizontal, DS.Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: DS.Size.sideTabItem)
        .background(shape.fill(isCurrent ? DS.Color.goldTint : (hovered ? DS.Color.bgHover : .clear)))
        .contentShape(shape)
        .opacity(configuration.isPressed ? DS.Opacity.pressed : 1)
        .onHover { hovered = $0 }
        .animation(DS.Motion.quick, value: hovered)
    }
  }
}

private struct SideTabLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: DS.Space.s3) {
      configuration.icon
        .font(.system(size: DS.Size.glyphLarge, weight: .medium))
        .frame(width: DS.Size.glyphLarge)
      configuration.title
    }
  }
}

/// Credit / about footer pinned to the bottom of the side tab bar. Clicking it opens the About panel,
/// which shows the license and open source credits (Resources/Credits.html).
private struct SideTabCredit: View {
  var body: some View {
    Button {
      NSApp.orderFrontStandardAboutPanel(nil)
    } label: {
      content
    }
    .buttonStyle(.plain)
    .help("About ViCut Lite · open source licenses")
  }

  private var content: some View {
    HStack(spacing: DS.Space.s2_5) {
      BrandMark()
        .frame(width: DS.Size.brandMarkCredit, height: DS.Size.brandMarkCredit)
      VStack(alignment: .leading, spacing: 0) {
        Text("Nhan Ta - Brian")
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.gold300)
        Text(Self.versionLine)
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
      }
      Spacer(minLength: 0)
    }
    .padding(.top, DS.Space.s3)
    .padding(.horizontal, DS.Space.s1_5)
    .padding(.bottom, DS.Space.s0_5)
    .overlay(alignment: .top) {
      Rectangle().fill(DS.Color.borderSubtle).frame(height: DS.Stroke.hairline)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  /// `swift run` has no bundle version, and the packaged Info.plist may still hold the
  /// unexpanded `__VERSION__` placeholder, so only show a real-looking version.
  private static var versionLine: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    guard let version, !version.isEmpty, !version.hasPrefix("__") else { return "ViCutLite" }
    return "ViCutLite \(version)"
  }
}

#Preview("Side tab bar") {
  SideTabBar(current: .history, onSelect: { _ in })
    .frame(height: 560)
    .background(DS.Color.bgApp)
}
