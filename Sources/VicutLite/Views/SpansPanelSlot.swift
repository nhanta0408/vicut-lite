import SwiftUI

/// Where the Spans list panel goes. `EditorView` places this view twice: docked to the right of
/// the stage when `model.spansPanel == .pinned`, and floating over the stage's trailing edge
/// when `.floating`. Intentionally empty until the panel is built; replace `body` with it.
struct SpansPanelSlot: View {
  let model: EditorModel
  let mode: SpansPanelMode

  var body: some View {
    EmptyView()
  }
}
