import SwiftUI

// Form controls for the Settings page, written generically so other pages can reuse them.

/// Overline label above a group card, e.g. "COMPRESSION".
struct SectionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .dsText(DS.Typography.overline)
      .foregroundStyle(DS.Color.textMuted)
      .padding(.horizontal, DS.Space.s1)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }
}

/// Labeled section: overline title over a card that stacks rows with hairline dividers.
struct SettingsSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(spacing: DS.Space.s2) {
      SectionLabel(title: title)
      VStack(spacing: 0) {
        content
      }
      .background(DS.Color.bgCard, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.xl)
          .strokeBorder(DS.Color.borderSubtle, lineWidth: DS.Size.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
    }
    .accessibilityElement(children: .contain)
  }
}

/// Hairline between rows of a `SettingsSection`.
struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(DS.Color.borderSubtle)
      .frame(height: DS.Size.hairline)
  }
}

/// One setting: label on the left (hint as tooltip), control on the right.
struct SettingsRow<Control: View>: View {
  let label: String
  var hint: String?
  @ViewBuilder let control: Control

  var body: some View {
    HStack(spacing: DS.Space.s4) {
      Text(label)
        .dsText(DS.Typography.bodyStrong)
        .foregroundStyle(DS.Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(hint ?? "")
      control
    }
    .padding(.vertical, DS.Space.s2)
    .padding(.leading, DS.Space.s4)
    .padding(.trailing, DS.Space.s3)
    .frame(minHeight: DS.Size.settingsRow)
  }
}

/// Switch row: the whole label is part of the toggle so clicking the text flips it too.
struct SettingsToggleRow: View {
  let label: String
  var hint: String?
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      Text(label)
        .dsText(DS.Typography.bodyStrong)
        .foregroundStyle(DS.Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .toggleStyle(GoldSwitchToggleStyle())
    .help(hint ?? "")
    .padding(.vertical, DS.Space.s2)
    .padding(.horizontal, DS.Space.s4)
    .frame(minHeight: DS.Size.settingsRow)
  }
}

/// Option for `SegmentedControl`; `hint` becomes the tooltip.
struct SegmentOption<Value: Hashable & Sendable>: Identifiable, Sendable {
  let value: Value
  let label: String
  var hint: String?

  var id: String { label }
}

/// Inset track with equal-width options; the selected one is filled gold (canvas: radiogroup).
struct SegmentedControl<Value: Hashable & Sendable>: View {
  let title: String
  let options: [SegmentOption<Value>]
  @Binding var selection: Value
  var width: CGFloat = DS.Size.segmentNarrow

  var body: some View {
    HStack(spacing: DS.Space.s0_75) {
      ForEach(options) { option in
        SegmentButton(option: option, isSelected: option.value == selection) {
          selection = option.value
        }
      }
    }
    .padding(DS.Space.s0_75)
    .frame(width: width)
    .background(DS.Color.bgInset, in: RoundedRectangle(cornerRadius: DS.Radius.track))
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.track)
        .strokeBorder(DS.Color.borderDefault, lineWidth: DS.Size.hairline)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel(title)
  }
}

private struct SegmentButton<Value: Hashable & Sendable>: View {
  let option: SegmentOption<Value>
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Text(option.label)
        .dsText(DS.Typography.label)
        .lineLimit(1)
        .foregroundStyle(foreground)
        .padding(.horizontal, DS.Space.s1_5)
        .frame(maxWidth: .infinity)
        .frame(height: DS.Size.segmentItem)
        .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(option.hint ?? "")
    .accessibilityLabel(option.label)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var foreground: Color {
    if isSelected { return DS.Color.onGold }
    return isHovered ? DS.Color.gold300 : DS.Color.textSecondary
  }

  private var background: Color {
    if isSelected { return DS.Color.gold500 }
    return isHovered ? DS.Color.bgHover : Color.clear
  }
}

/// Pill switch: gold track when on, `border.strong` when off. Apply with `.toggleStyle(GoldSwitchToggleStyle())`.
struct GoldSwitchToggleStyle: ToggleStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: DS.Space.s4) {
      configuration.label
      Button {
        withAnimation(reduceMotion ? nil : DS.Motion.quick) {
          configuration.isOn.toggle()
        }
      } label: {
        Capsule()
          .fill(configuration.isOn ? DS.Color.gold500 : DS.Color.borderStrong)
          .frame(width: DS.Size.toggleWidth, height: DS.Size.toggleHeight)
          .overlay(alignment: configuration.isOn ? .trailing : .leading) {
            Circle()
              .fill(DS.Color.textPrimary)
              .frame(width: DS.Size.toggleKnob, height: DS.Size.toggleKnob)
              .padding(DS.Space.s0_75)
          }
          .contentShape(Capsule())
      }
      .buttonStyle(.plain)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }
    }
  }
}

/// Single-line Menlo input on the inset surface; border turns gold while editing.
struct InsetTextField: View {
  let title: String
  @Binding var text: String
  var width: CGFloat = DS.Size.inputShort
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField(title, text: $text)
      .textFieldStyle(.plain)
      .labelsHidden()
      .autocorrectionDisabled()
      .dsText(DS.Typography.label)
      .foregroundStyle(DS.Color.textPrimary)
      .focused($isFocused)
      .padding(.horizontal, DS.Space.s2_5)
      .frame(width: width, height: DS.Size.inputHeight)
      .background(DS.Color.bgInset, in: RoundedRectangle(cornerRadius: DS.Radius.md))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.md)
          .strokeBorder(isFocused ? DS.Color.gold500 : DS.Color.borderStrong, lineWidth: DS.Size.hairline)
      )
      .accessibilityLabel(title)
  }
}
