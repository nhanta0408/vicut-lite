import SwiftUI

/// What a drop does with the chosen videos.
enum DropAction {
  case compress
  case edit
}

/// The single drop target on Home. The whole Home screen accepts drops; this view only shows the
/// affordance and lights up while a drag hovers the window. Prominent = the empty-queue state,
/// where it fills the page; otherwise it's a slim bar above the list.
struct DropZoneView: View {
  let isTargeted: Bool
  /// ⌥ is held during the drag: releasing opens the editor instead of compressing.
  var opensEditor = false
  var isProminent = false

  private var title: String {
    guard isTargeted else { return "Drop videos to compress" }
    return opensEditor ? "Release to edit" : "Release to compress"
  }

  private var icon: String {
    isTargeted && opensEditor ? "scissors" : "square.and.arrow.down"
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
    content
      .background(shape.fill(isTargeted ? DS.Color.goldWashActive : DS.Color.goldWash))
      .overlay(
        shape.strokeBorder(
          isTargeted ? DS.Color.gold500 : DS.Color.borderGold,
          style: StrokeStyle(lineWidth: DS.Stroke.emphasis, dash: DS.Stroke.dash)
        )
      )
      .help("Drop videos to compress. Hold ⌥ while dropping to open the editor first.")
      .animation(DS.Motion.quick, value: isTargeted)
  }

  @ViewBuilder
  private var content: some View {
    if isProminent {
      VStack(spacing: DS.Space.s3) {
        DSIcon(icon, size: DS.Size.emptyStateGlyph)
          .foregroundStyle(DS.Color.gold500)
        Text(title)
          .dsText(DS.Typography.heading)
          .foregroundStyle(isTargeted ? DS.Color.gold300 : DS.Color.textPrimary)
        Text(opensEditor && isTargeted ? "Opens the editor instead of compressing." : "Hold ⌥ while dropping to open the editor instead.")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
          .multilineTextAlignment(.center)
      }
      .padding(DS.Space.s5)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      HStack(spacing: DS.Space.s3) {
        DSIcon(icon, size: DS.Size.glyphLarge)
          .foregroundStyle(DS.Color.gold500)
        Text(isTargeted && !opensEditor ? "Release to compress · hold ⌥ to edit" : title)
          .dsText(DS.Typography.body)
          .foregroundStyle(isTargeted ? DS.Color.gold300 : DS.Color.textSecondary)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, DS.Space.s3)
      .frame(height: DS.Size.dropZone)
    }
  }
}
