import SwiftUI
import VicutCore

/// Asks before an edit wipes out cut / speed spans that lie completely inside it.
struct OverlapDialog: View {
  let pending: PendingReplace
  let onCancel: () -> Void
  let onConfirm: () -> Void

  var body: some View {
    let covered = pending.impact.covered
    EditorKit.Dialog(title: "Replace \(covered.count == 1 ? "1 span" : "\(covered.count) spans")?") {
      (
        Text("\(pending.action.title) will cover ")
          + Text(EditorModel.rangeText(pending.range)).foregroundStyle(DS.Color.gold300)
          + Text(". These spans are fully inside it and will be removed:")
      )
      .dsText(DS.Typography.body)
      .foregroundStyle(DS.Color.textSecondary)
      .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: DS.Space.s1_5) {
        ForEach(covered, id: \.self) { span in
          HStack(spacing: DS.Space.s2) {
            EditorKit.Swatch(color: span.action.swatch)
            Text(span.action.title)
              .dsText(DS.Typography.label)
              .foregroundStyle(DS.Color.textPrimary)
            Text(EditorModel.rangeText(span.start...span.end))
              .dsText(DS.Typography.label.regular)
              .foregroundStyle(DS.Color.textMuted)
              .monospacedDigit()
            Spacer()
          }
          .padding(.horizontal, DS.Space.s3)
          .padding(.vertical, DS.Space.s2)
          .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Color.bgInset))
          .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Color.borderDefault, lineWidth: DS.Size.hairline))
        }
      }

      if !pending.impact.trimmed.isEmpty {
        Text("Also trimmed: " + pending.impact.trimmed.map(\.action.title).joined(separator: " · "))
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
      }
    } actions: {
      Button("Keep spans", action: onCancel)
        .buttonStyle(EditorKit.GhostButtonStyle())
        .keyboardShortcut(.cancelAction)
      Button("Replace", action: onConfirm)
        .buttonStyle(EditorKit.PrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
    }
  }
}
