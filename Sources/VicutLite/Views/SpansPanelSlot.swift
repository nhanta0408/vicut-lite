import SwiftUI
import VicutCore

/// The Spans list. `EditorView` places it docked right of the stage when `.pinned` and over the
/// stage's trailing edge when `.floating`; the panel itself only changes chrome between the two.
struct SpansPanelSlot: View {
  let model: EditorModel
  let mode: SpansPanelMode

  @FocusState private var focus: SpanTimeField?
  /// Row whose type menu is open.
  @State private var menuRow: Int?

  var body: some View {
    let spans = model.editedSpans
    VStack(spacing: 0) {
      header(count: spans.count)
      list(spans)
    }
    .frame(width: DS.Size.spansPanel)
    .frame(maxHeight: .infinity)
    .background(DS.Color.bgChrome)
    .overlayPreferenceValue(SpanTypeMenuAnchorKey.self) { anchors in
      typeMenu(spans: spans, anchors: anchors)
    }
    .clipShape(RoundedRectangle(cornerRadius: radius))
    .overlay { chromeBorder }
    .shadow(color: mode == .floating ? DS.Color.shadow : .clear, radius: DS.Size.panelShadowRadius, y: DS.Size.panelShadowY)
    .onChange(of: focus) { _, field in
      if model.focusedTimeField != field { model.focusedTimeField = field }
    }
    .onChange(of: model.focusedTimeField) { _, field in
      if focus != field { focus = field }
    }
    .onDisappear { model.focusedTimeField = nil }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Spans")
  }

  private var radius: CGFloat { mode == .floating ? DS.Radius.xl : 0 }

  /// Floating: full outline. Docked: only the edge facing the stage.
  @ViewBuilder
  private var chromeBorder: some View {
    if mode == .floating {
      RoundedRectangle(cornerRadius: radius).strokeBorder(DS.Color.borderDefault, lineWidth: DS.Size.hairline)
    } else {
      HStack {
        Rectangle().fill(DS.Color.borderDefault).frame(width: DS.Size.hairline)
        Spacer()
      }
    }
  }

  // MARK: Header

  private func header(count: Int) -> some View {
    HStack(spacing: DS.Space.s2) {
      Text("Spans")
        .dsText(DS.Typography.heading)
        .foregroundStyle(DS.Color.textPrimary)
        .accessibilityAddTraits(.isHeader)
        .help("Edit times directly. Partial overlaps trim the neighbour; fully covered spans ask before removal. Normal parts are not listed.")
      Text("\(count)")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .monospacedDigit()
      Spacer()
      pinButton
      Button {
        model.spansPanel = .closed
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(EditorKit.IconButtonStyle(size: DS.Size.iconButtonSmall, tint: DS.Color.textMuted))
      .help("Close")
      .accessibilityLabel("Close spans")
    }
    .padding(.leading, DS.Space.s4)
    .padding(.trailing, DS.Space.s2)
    .frame(height: DS.Size.spansHeader)
    .overlay(alignment: .bottom) {
      Rectangle().fill(DS.Color.borderSubtle).frame(height: DS.Size.hairline)
    }
  }

  private var pinButton: some View {
    let pinned = mode == .pinned
    let label = pinned ? "Unpin panel" : "Pin panel to the side"
    return Button {
      model.spansPanel = pinned ? .floating : .pinned
    } label: {
      Image(systemName: pinned ? "pin.fill" : "pin")
    }
    // Tinted without the active outline: the canvas pin only fills when docked.
    .buttonStyle(EditorKit.IconButtonStyle(size: DS.Size.iconButtonSmall, tint: pinned ? DS.Color.gold300 : DS.Color.textMuted))
    .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(pinned ? DS.Color.goldTint : .clear))
    .help(label)
    .accessibilityLabel(label)
    .accessibilityAddTraits(pinned ? .isSelected : [])
  }

  // MARK: List

  @ViewBuilder
  private func list(_ spans: [Segment]) -> some View {
    if spans.isEmpty {
      emptyState
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: DS.Space.s1_5) {
            // Rows are keyed by position: spans are re-resolved after every edit, and a stable
            // key keeps a focused time field alive while its neighbour is being committed.
            ForEach(Array(spans.enumerated()), id: \.offset) { index, span in
              row(index: index, span: span, isSelected: isSelected(span))
                .id(index)
            }
          }
          .padding(.horizontal, DS.Space.s3)
          .padding(.vertical, DS.Space.s2_5)
        }
        .onChange(of: model.selectedSpan) { _, span in
          guard let span, let index = spans.firstIndex(of: span) else { return }
          withAnimation(DS.Motion.quick) { proxy.scrollTo(index) }
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: DS.Space.s2) {
      Image(systemName: "list.bullet")
        .font(.system(size: DS.Size.emptyGlyph, weight: .light))
        .foregroundStyle(DS.Color.textFaint)
      Text("No edits yet")
        .dsText(DS.Typography.label)
        .foregroundStyle(DS.Color.textSecondary)
      Text("Drag on the timeline or press I / O, then C to cut or 2 / 4 to speed up. Cuts and speed-ups show here.")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .multilineTextAlignment(.center)
    }
    .padding(DS.Space.s6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }


  private func isSelected(_ span: Segment) -> Bool {
    model.selection == nil && model.selectedSpan == span
  }

  private func row(index: Int, span: Segment, isSelected: Bool) -> some View {
    HStack(spacing: DS.Space.s2) {
      RoundedRectangle(cornerRadius: DS.Radius.spanRowBar)
        .fill(span.action.swatch)
        .frame(width: DS.Size.spanRowBar)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: DS.Space.s1_5) {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s2) {
          Text(span.action.title)
            .dsText(DS.Typography.label)
            .foregroundStyle(span.action.titleColor)
          Text(Self.lengthText(span))
            .dsText(DS.Typography.caption)
            .foregroundStyle(DS.Color.textFaint)
            .monospacedDigit()
        }
        HStack(spacing: DS.Space.s1_5) {
          timeField(index: index, span: span, isEnd: false)
          Image(systemName: "arrow.right")
            .font(.system(size: DS.Size.iconTiny, weight: .semibold))
            .foregroundStyle(DS.Color.textFaint)
            .accessibilityHidden(true)
          timeField(index: index, span: span, isEnd: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: DS.Space.s0_5) {
        typeButton(index: index, span: span)
        deleteButton(index: index, span: span)
      }
    }
    .padding(.vertical, DS.Space.s2)
    .padding(.leading, DS.Space.s3)
    .padding(.trailing, DS.Space.s2)
    .background {
      // Tap target sits behind the fields so clicking into a field doesn't also end editing.
      RoundedRectangle(cornerRadius: DS.Radius.button)
        .fill(isSelected ? DS.Color.spanRowSelected : DS.Color.spanRowBg)
        .contentShape(Rectangle())
        .onTapGesture {
          menuRow = nil
          model.selectSpan(at: Self.mid(span))
          model.seek(to: span.start)
        }
    }
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.button)
        .strokeBorder(isSelected ? DS.Color.gold500 : DS.Color.spanRowBorder, lineWidth: DS.Size.hairline)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Span \(index + 1), \(span.action.title), \(EditorModel.rangeText(span.start...span.end, separator: " to "))")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func timeField(index: Int, span: Segment, isEnd: Bool) -> some View {
    SpanTimeInput(
      value: isEnd ? span.end : span.start,
      field: SpanTimeField(row: index, isEnd: isEnd),
      focus: $focus,
      accessibilityLabel: "Span \(index + 1) \(isEnd ? "end" : "start")",
      onFocus: {
        menuRow = nil
        model.highlightSpan(at: Self.mid(span))
      },
      onCommit: { text in commit(text, span: span, isEnd: isEnd) }
    )
  }

  private func commit(_ text: String, span: Segment, isEnd: Bool) {
    let parsed = TimeCode.parse(text)
    let start = isEnd ? span.start : parsed
    let end = isEnd ? parsed : span.end
    guard let start, let end, start < end else {
      model.rejectTypedTime()
      return
    }
    model.retime(span, to: start...end)
  }

  private func typeButton(index: Int, span: Segment) -> some View {
    let isOpen = menuRow == index
    return Button {
      model.selectSpan(at: Self.mid(span))
      menuRow = isOpen ? nil : index
    } label: {
      Image(systemName: "pencil")
    }
    .buttonStyle(EditorKit.IconButtonStyle(size: DS.Size.iconButtonSmall, isActive: isOpen))
    .anchorPreference(key: SpanTypeMenuAnchorKey.self, value: .bounds) { [index: $0] }
    .help("Change span type")
    .accessibilityLabel("Change type of span \(index + 1)")
  }

  /// Deleting a span means turning it back to Normal; it then merges with its Normal neighbours.
  private func deleteButton(index: Int, span: Segment) -> some View {
    Button {
      menuRow = nil
      model.selectSpan(at: Self.mid(span))
      model.apply(.keep)
    } label: {
      Image(systemName: "eraser")
    }
    .buttonStyle(EditorKit.IconButtonStyle(size: DS.Size.iconButtonSmall, tint: DS.Color.dangerText))
    .help("Clear edit (back to Normal)")
    .accessibilityLabel("Clear edit on span \(index + 1)")
  }

  /// Drawn over the whole panel so it isn't clipped by the scroll view or the row.
  @ViewBuilder
  private func typeMenu(spans: [Segment], anchors: [Int: Anchor<CGRect>]) -> some View {
    if let row = menuRow, spans.indices.contains(row), let anchor = anchors[row] {
      let span = spans[row]
      GeometryReader { proxy in
        let button = proxy[anchor]
        let menuHeight = CGFloat(SegmentAction.menuChoices(current: span.action).count) * DS.Size.editorMenuItem
          + DS.Space.s1_5 * 2
        // Opens below the button, or above it when the row is near the bottom of the panel.
        let below = button.maxY + DS.Space.s1 + menuHeight <= proxy.size.height
        ZStack(alignment: .topLeading) {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture { menuRow = nil }
          EditorKit.Menu(width: DS.Size.spanTypeMenu) {
            ForEach(SegmentAction.menuChoices(current: span.action), id: \.self) { action in
              EditorKit.MenuItem(title: action.title, swatch: action.swatch, isChecked: span.action == action) {
                menuRow = nil
                model.selectSpan(at: Self.mid(span))
                model.apply(action)
              }
            }
          }
          .accessibilityLabel("Span type")
          .offset(
            x: max(button.maxX - DS.Size.spanTypeMenu, DS.Space.s2),
            y: below ? button.maxY + DS.Space.s1 : max(button.minY - DS.Space.s1 - menuHeight, DS.Space.s2)
          )
        }
      }
      .onExitCommand { menuRow = nil }
    }
  }

  private static func mid(_ span: Segment) -> Double {
    (span.start + span.end) / 2
  }

  /// "3.3s", and for sped-up spans the length it plays for: "5s → 2.5s".
  static func lengthText(_ span: Segment) -> String {
    let length = seconds(span.length)
    guard case .speed(let factor) = span.action, factor > 0 else { return length }
    return "\(length) → \(seconds(span.length / factor))"
  }

  private static func seconds(_ value: Double) -> String {
    String(format: "%gs", (value * 10).rounded() / 10)
  }
}

/// One start / end field. Keeps its own draft text and commits only when focus leaves, so
/// Return, Tab and clicking away all behave the same; Escape throws the draft away.
private struct SpanTimeInput: View {
  let value: Double
  let field: SpanTimeField
  var focus: FocusState<SpanTimeField?>.Binding
  let accessibilityLabel: String
  let onFocus: () -> Void
  let onCommit: (String) -> Void

  @State private var text = ""
  @State private var discard = false

  private var isFocused: Bool { focus.wrappedValue == field }
  private var formatted: String { Formatters.duration(value) }

  var body: some View {
    TextField("", text: $text)
      .textFieldStyle(.plain)
      .dsText(DS.Typography.label.regular)
      .foregroundStyle(DS.Color.textPrimary)
      .multilineTextAlignment(.center)
      .monospacedDigit()
      .focused(focus, equals: field)
      .frame(width: DS.Size.timeFieldWidth, height: DS.Size.timeFieldHeight)
      .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(isFocused ? DS.Color.timeFieldFocus : DS.Color.bgInset))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.sm)
          .strokeBorder(isFocused ? DS.Color.gold500 : DS.Color.borderStrong, lineWidth: DS.Size.hairline)
      )
      .accessibilityLabel(accessibilityLabel)
      .onAppear { text = formatted }
      .onChange(of: value) {
        if !isFocused { text = formatted }
      }
      .onSubmit { focus.wrappedValue = nil }
      .onExitCommand {
        discard = true
        focus.wrappedValue = nil
      }
      .onChange(of: isFocused) { _, focused in
        if focused {
          onFocus()
          return
        }
        let draft = text.trimmingCharacters(in: .whitespaces)
        text = formatted
        if discard {
          discard = false
        } else if draft != formatted {
          onCommit(draft)
        }
      }
  }
}

/// Bounds of each row's type button, keyed by row, so the menu can be drawn above the list.
private struct SpanTypeMenuAnchorKey: PreferenceKey {
  static let defaultValue: [Int: Anchor<CGRect>] = [:]

  static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
    value.merge(nextValue()) { current, _ in current }
  }
}
