import SwiftUI
import VicutCore

/// Opened from the timeline header: retype the selection / selected span, or add a span at the playhead.
struct EditSpanMenu: View {
  let model: EditorModel
  let close: () -> Void

  var body: some View {
    let target = model.editTarget
    EditorKit.Menu {
      EditorKit.MenuHeader(text: model.selection == nil ? "Selected span" : "Selection")
      ForEach(SegmentAction.menuChoices(current: target?.action), id: \.self) { action in
        EditorKit.MenuItem(
          title: action.title,
          swatch: action.swatch,
          isChecked: target?.action == action,
          isEnabled: target != nil
        ) {
          close()
          model.apply(action)
        }
      }

      EditorKit.MenuDivider()
      EditorKit.MenuHeader(text: "New at playhead · \(String(format: "%gs", EditorModel.newSpanLength))")
      EditorKit.MenuItem(title: "Add cut", swatch: SegmentAction.cut.swatch) {
        close()
        model.addAtPlayhead(.cut)
      }
      EditorKit.MenuItem(title: "Add \(Formatters.speed(2)) speed", swatch: SegmentAction.speed(2).swatch) {
        close()
        model.addAtPlayhead(.speed(2))
      }

      EditorKit.MenuDivider()
      EditorKit.MenuItem(title: "Reset all edits", systemImage: "arrow.counterclockwise", isEnabled: !model.marks.isEmpty) {
        close()
        model.resetAll()
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Span actions")
  }
}
