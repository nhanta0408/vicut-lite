import SwiftUI

// Components used by the History page. Kept separate from Components.swift until the
// design-system files are consolidated.

/// Gold pill with the size reduction, e.g. "−98%" (canvas: "Saved badge").
struct SavedBadge: View {
  let percent: Int

  var body: some View {
    Text(Self.label(percent))
      .dsText(DS.Typography.micro)
      .foregroundStyle(DS.Color.onGold)
      .padding(.horizontal, DS.Space.badgeX)
      .padding(.vertical, DS.Space.s0_5)
      .background(DS.Color.gold500, in: Capsule())
  }

  /// A grown file reads "+12%" so it is never mistaken for a saving.
  static func label(_ percent: Int) -> String {
    percent >= 0 ? "−\(percent)%" : "+\(-percent)%"
  }
}

/// Outlined danger pill shown when an exported file was moved or deleted.
struct NotFoundBadge: View {
  var body: some View {
    Text("Not found")
      .dsText(DS.Typography.micro)
      .foregroundStyle(DS.Color.dangerText)
      .padding(.horizontal, DS.Space.s2)
      .padding(.vertical, DS.Space.s0_5)
      .overlay(Capsule().strokeBorder(DS.Color.dangerBorder, lineWidth: DS.Size.hairline))
  }
}

/// Overline section label with a faint count, e.g. "TODAY 2".
struct HistoryGroupHeader: View {
  let title: String
  let count: Int

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: DS.Space.s2) {
      Text(title)
        .dsText(DS.Typography.overline)
        .foregroundStyle(DS.Color.textMuted)
      Text("\(count)")
        .dsText(DS.Typography.overline)
        .textCase(nil)
        .foregroundStyle(DS.Color.textFaint)
    }
    .padding(.horizontal, DS.Space.s1)
    .padding(.top, DS.Space.s2)
    .padding(.bottom, DS.Space.s0_5)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Transparent square button with a border; hover tints it like the canvas `.vc-icon-btn`.
struct GhostIconButtonStyle: ButtonStyle {
  var size: CGFloat = DS.Size.iconButtonSm

  func makeBody(configuration: Configuration) -> some View {
    GhostChrome(configuration: configuration, radius: DS.Radius.sm) {
      configuration.label
        .font(.system(size: DS.Size.iconGlyph))
        .frame(width: size, height: size)
    }
  }
}

/// Text ghost button (e.g. "Clear"), same chrome as the Settings "Restore defaults" button.
struct GhostTextButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    GhostChrome(configuration: configuration, radius: DS.Radius.md) {
      configuration.label
        .dsText(DS.Typography.label)
        .padding(.horizontal, DS.Space.s3)
        .frame(height: DS.Size.iconButtonSm)
    }
  }
}

private struct GhostChrome<Content: View>: View {
  let configuration: ButtonStyleConfiguration
  let radius: CGFloat
  @ViewBuilder let content: Content
  @State private var isHovered = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let active = isEnabled && (isHovered || configuration.isPressed)
    content
      .foregroundStyle(active ? DS.Color.gold300 : DS.Color.textSecondary)
      .background(active ? DS.Color.bgHover : SwiftUI.Color.clear, in: RoundedRectangle(cornerRadius: radius))
      .overlay(
        RoundedRectangle(cornerRadius: radius)
          .strokeBorder(DS.Color.borderDefault, lineWidth: DS.Size.hairline)
      )
      .contentShape(RoundedRectangle(cornerRadius: radius))
      .opacity(isEnabled ? 1 : DS.Opacity.disabled)
      .onHover { isHovered = $0 }
  }
}
