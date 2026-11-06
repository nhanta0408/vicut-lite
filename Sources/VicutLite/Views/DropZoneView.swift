import SwiftUI

/// What a drop or file pick does with the chosen videos.
enum DropAction {
  case compress
  case edit
}

/// Dashed drop bar at the top of the Queue. The whole Home screen accepts drops;
/// this view only shows the affordance and lights up while a drag hovers the window.
struct DropZoneView: View {
  let isTargeted: Bool

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
    HStack(spacing: DS.Space.s3) {
      DSIcon("square.and.arrow.down", size: DS.Size.glyphLarge)
        .foregroundStyle(DS.Color.gold500)
      Text(isTargeted ? "Release to compress · hold ⌥ to edit first" : "Drop videos to compress")
        .dsText(DS.Typography.body)
        .foregroundStyle(isTargeted ? DS.Color.gold300 : DS.Color.textSecondary)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, DS.Space.s3)
    .frame(height: DS.Size.dropZone)
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
}
