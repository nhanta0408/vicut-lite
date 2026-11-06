import SwiftUI

// Components used only by the History page; shared buttons live in Components.swift.

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
