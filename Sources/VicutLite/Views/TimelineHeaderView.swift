import SwiftUI
import VicutCore

/// Row above the track: what's selected + edit button, undo, zoom, and the Spans panel toggle.
struct TimelineHeaderView: View {
  let model: EditorModel
  @Binding var isEditMenuOpen: Bool

  var body: some View {
    HStack(spacing: DS.Space.s2) {
      targetSummary
      editButton
      Spacer(minLength: DS.Space.s3)
      undoButton
      zoomControls
      spansToggle
    }
    .frame(height: DS.Size.timelineHeader)
  }

  @ViewBuilder
  private var targetSummary: some View {
    if let selection = model.selection {
      summary(swatch: DS.Color.gold500, title: "Selection", color: DS.Color.gold300, range: selection)
    } else if let span = model.selectedSpan {
      summary(swatch: span.action.swatch, title: span.action.title, color: span.action.titleColor, range: span.start...span.end)
    } else {
      Text("Click a span or drag to select")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
    }
  }

  private func summary(swatch: Color, title: String, color: Color, range: ClosedRange<Double>) -> some View {
    HStack(spacing: DS.Space.s2) {
      EditorKit.Swatch(color: swatch)
      Text(title)
        .dsText(DS.Typography.label)
        .foregroundStyle(color)
      Text(EditorModel.rangeText(range))
        .dsText(DS.Typography.label.regular)
        .foregroundStyle(DS.Color.textMuted)
        .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
  }

  private var editButton: some View {
    Button {
      isEditMenuOpen.toggle()
    } label: {
      Image(systemName: "pencil")
    }
    .buttonStyle(EditorKit.IconButtonStyle(isActive: isEditMenuOpen, bordered: true, tint: DS.Color.gold300))
    .anchorPreference(key: EditMenuAnchorKey.self, value: .bounds) { $0 }
    .help("Edit selected span · add a span at the playhead")
    .accessibilityLabel("Edit selected span")
  }

  private var undoButton: some View {
    Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
      .buttonStyle(EditorKit.IconButtonStyle())
      .keyboardShortcut("z", modifiers: .command)
      .disabled(!model.canUndo)
      .help("Undo (⌘Z)")
      .accessibilityLabel("Undo")
  }

  private var zoomControls: some View {
    HStack(spacing: DS.Space.s0_5) {
      Button { model.zoom(by: 1 / EditorModel.zoomStep) } label: { Image(systemName: "minus.magnifyingglass") }
        .keyboardShortcut("-", modifiers: .command)
        .help("Zoom out (⌘−)")
        .accessibilityLabel("Zoom out")
        .disabled(!model.viewport.isZoomed)
      Text(zoomLabel)
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .monospacedDigit()
        .frame(minWidth: DS.Size.zoomLabel)
        .accessibilityLabel("Visible span \(zoomLabel)")
      Button { model.zoom(by: EditorModel.zoomStep) } label: { Image(systemName: "plus.magnifyingglass") }
        .keyboardShortcut("=", modifiers: .command)
        .help("Zoom in (⌘+) · pinch or ⌥-scroll on the timeline")
        .accessibilityLabel("Zoom in")
        .disabled(model.viewport.span <= TimelineViewport.minSpan)
      Button { model.zoomToFit() } label: { Image(systemName: "arrow.left.and.right") }
        .keyboardShortcut("0", modifiers: .command)
        .help("Show the whole clip (⌘0)")
        .accessibilityLabel("Fit whole clip")
        .disabled(!model.viewport.isZoomed)
      Button { model.zoomToSelection() } label: { Image(systemName: "viewfinder") }
        .keyboardShortcut(model.focusedTimeField == nil ? KeyboardShortcut("z", modifiers: []) : nil)
        .help("Zoom to the selection (Z)")
        .accessibilityLabel("Zoom to selection")
        .disabled(model.editTarget == nil)
    }
    .buttonStyle(EditorKit.IconButtonStyle())
  }

  /// Visible span is more useful than a raw factor when editing a 5s part of a 30min clip.
  private var zoomLabel: String {
    model.viewport.isZoomed ? Formatters.duration(model.viewport.span) : "All"
  }

  private var spansToggle: some View {
    let isOpen = model.spansPanel.isOpen
    return Button {
      model.spansPanel = isOpen ? .closed : .floating
      isEditMenuOpen = false
    } label: {
      HStack(spacing: DS.Space.s1_5) {
        Image(systemName: "list.bullet")
          .font(.system(size: DS.Size.iconSmall, weight: .semibold))
        Text("Spans")
        EditorKit.Pill(
          text: "\(model.resolved.count)",
          foreground: DS.Color.textSecondary,
          fill: DS.Color.bgPill,
          border: nil
        )
      }
    }
    .buttonStyle(EditorKit.GhostButtonStyle(height: DS.Size.editorIconButton, isActive: isOpen))
    .help("Show the list of spans")
    .accessibilityAddTraits(isOpen ? .isSelected : [])
  }
}

/// Bounds of the edit button, so the menu can be drawn at window level above it.
struct EditMenuAnchorKey: PreferenceKey {
  static let defaultValue: Anchor<CGRect>? = nil

  static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
    value = value ?? nextValue()
  }
}

extension DS.TextStyle {
  /// Same metrics without bold, for values sitting next to a bold label.
  var regular: DS.TextStyle {
    DS.TextStyle(size: size, bold: false, lineHeight: lineHeight, tracking: tracking, uppercase: uppercase)
  }
}
