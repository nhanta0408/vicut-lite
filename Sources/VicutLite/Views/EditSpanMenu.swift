import SwiftUI
import VicutCore

/// Opened from the timeline header: retype the selection / selected span, or reset all edits.
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
      EditorKit.MenuItem(title: "Reset all edits", systemImage: "arrow.counterclockwise", isEnabled: !model.marks.isEmpty) {
        close()
        model.resetAll()
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Span actions")
  }
}
