import SwiftUI

enum DropAction {
  case compress
  case edit

  var title: String {
    switch self {
    case .compress: "Compress"
    case .edit: "Cut / Speed up"
    }
  }

  var subtitle: String {
    switch self {
    case .compress: "Shrink to a GitHub-ready .mp4 right away"
    case .edit: "Open the editor, then export full quality or compressed"
    }
  }

  var systemImage: String {
    switch self {
    case .compress: "arrow.down.right.and.arrow.up.left"
    case .edit: "scissors"
    }
  }
}

/// One drop target per action, so compressing and editing stay independent.
struct DropZoneView: View {
  let action: DropAction
  let compact: Bool
  let onDrop: ([URL]) -> Bool
  let onChoose: () -> Void
  @State private var isTargeted = false

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity)
      .padding(compact ? 10 : 16)
      .background(
        RoundedRectangle(cornerRadius: compact ? 10 : 14)
          .fill(isTargeted ? Color.accentColor.opacity(0.1) : .clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: compact ? 10 : 14)
          .strokeBorder(
            isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
          )
      )
      .contentShape(Rectangle())
      .dropDestination(for: URL.self) { urls, _ in
        onDrop(urls)
      } isTargeted: { isTargeted = $0 }
      .animation(.easeOut(duration: 0.15), value: isTargeted)
  }

  @ViewBuilder private var content: some View {
    if compact {
      HStack(spacing: 8) {
        Image(systemName: action.systemImage)
          .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
        Text("Drop to \(action.title.lowercased())")
          .font(.callout.weight(.medium))
          .lineLimit(1)
        Spacer(minLength: 4)
        Button("Choose…", action: onChoose)
          .controlSize(.small)
      }
    } else {
      VStack(spacing: 10) {
        Image(systemName: action.systemImage)
          .font(.system(size: 36, weight: .light))
          .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
        Text(action.title)
          .font(.title3.weight(.semibold))
        Text(action.subtitle)
          .font(.callout)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Button("Choose File…", action: onChoose)
      }
    }
  }
}
