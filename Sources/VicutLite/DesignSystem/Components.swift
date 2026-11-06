import SwiftUI

// Reusable building blocks for every ViCut Lite window. Each one maps to a row of the
// "Element → token mapping" table on the Design system artboard.

// MARK: - Button sizing

extension DS {
  /// Height + corner radius pairs used by buttons (36 → radius.md, 40 → radius.lg).
  enum ButtonSize {
    /// 28 pt: header actions such as "Select".
    case small
    /// 32 pt: title-bar icons, page-header actions (Clear, Restore defaults, Show in Finder).
    case medium
    /// 36 pt: buttons inside a button group.
    case regular
    /// 38 pt: dialog actions, preset chip.
    case dialog
    /// 40 pt: standalone row / footer actions.
    case large

    var height: CGFloat {
      switch self {
      case .small: DS.Size.hitMin
      case .medium: DS.Size.iconButtonSmall
      case .regular: DS.Size.iconButton
      case .dialog: DS.Size.buttonDialog
      case .large: DS.Size.buttonLarge
      }
    }

    var radius: CGFloat {
      switch self {
      case .small: DS.Radius.sm
      case .medium, .regular, .dialog: DS.Radius.md
      case .large: DS.Radius.lg
      }
    }

    var paddingX: CGFloat {
      switch self {
      case .small: DS.Space.s2
      case .medium, .regular, .dialog: DS.Space.s3
      case .large: DS.Space.s4
      }
    }

    var text: DS.TextStyle {
      switch self {
      case .small, .medium, .regular: DS.Typography.label
      case .dialog, .large: DS.Typography.bodyBold
      }
    }
  }
}

// MARK: - Button styles

/// Gold fill, dark label. One per area: Edit, Add videos, Export.
struct DSPrimaryButtonStyle: ButtonStyle {
  var size: DS.ButtonSize = .regular
  /// Adds the gold ring + glow used by the window's main call to action.
  var glow = false

  func makeBody(configuration: Configuration) -> some View {
    DSButtonBody(configuration: configuration, size: size) { hovered, _ in
      DSButtonColors(
        fill: hovered ? DS.Color.gold400 : DS.Color.gold500,
        border: .clear,
        label: DS.Color.onGold
      )
    }
    .shadow(color: glow ? DS.Color.goldGlow : .clear, radius: DS.Shadow.glowRadius, y: DS.Shadow.glowY)
    .overlay {
      if glow {
        RoundedRectangle(cornerRadius: size.radius)
          .strokeBorder(DS.Color.goldRing, lineWidth: DS.Stroke.hairline)
      }
    }
  }
}

/// Transparent with a strong border: Cancel, Settings. `isActive` shows the pressed-toggle look.
struct DSGhostButtonStyle: ButtonStyle {
  var size: DS.ButtonSize = .regular
  var isActive = false
  /// Drops the border for text-only actions such as "Select all finished".
  var bordered = true
  /// border.default instead of border.strong: page-header actions sitting on bg.app.
  var quiet = false

  func makeBody(configuration: Configuration) -> some View {
    DSButtonBody(configuration: configuration, size: size) { hovered, _ in
      if isActive {
        DSButtonColors(fill: DS.Color.goldTint, border: DS.Color.gold500, label: DS.Color.gold300)
      } else {
        DSButtonColors(
          fill: hovered ? DS.Color.bgHover : .clear,
          border: bordered ? (quiet ? DS.Color.borderDefault : DS.Color.borderStrong) : .clear,
          label: hovered || !bordered ? DS.Color.gold300 : DS.Color.textSecondary
        )
      }
    }
  }
}

/// Inset well (bg.inset + border.default): secondary actions on a card, e.g. Cancel, Edit first.
struct DSInsetButtonStyle: ButtonStyle {
  var size: DS.ButtonSize = .large

  func makeBody(configuration: Configuration) -> some View {
    DSButtonBody(configuration: configuration, size: size) { hovered, _ in
      DSButtonColors(
        fill: hovered ? DS.Color.bgHover : DS.Color.bgInset,
        border: DS.Color.borderDefault,
        label: hovered ? DS.Color.gold300 : DS.Color.textSecondary
      )
    }
  }
}

/// Solid danger: destructive confirmations (Delete originals, Move to Trash).
struct DSDangerButtonStyle: ButtonStyle {
  var size: DS.ButtonSize = .large

  func makeBody(configuration: Configuration) -> some View {
    DSButtonBody(configuration: configuration, size: size) { hovered, _ in
      DSButtonColors(fill: hovered ? DS.Color.danger400 : DS.Color.danger500, border: .clear, label: DS.Color.onGold)
    }
  }
}

/// Square icon-only button. `tone: .danger` turns red on hover (delete original).
struct DSIconButtonStyle: ButtonStyle {
  enum Tone {
    case neutral
    case danger
  }

  var size: DS.ButtonSize = .regular
  var tone: Tone = .neutral
  var bordered = false
  /// Inset well background, for standalone icon buttons on a card.
  var inset = false
  var isActive = false
  /// border.default instead of border.strong, same as `DSGhostButtonStyle.quiet`.
  var quiet = false

  func makeBody(configuration: Configuration) -> some View {
    DSButtonBody(configuration: configuration, size: size, square: true) { hovered, _ in
      let rest = inset ? DS.Color.bgInset : SwiftUI.Color.clear
      let border = bordered ? (inset || quiet ? DS.Color.borderDefault : DS.Color.borderStrong) : .clear
      switch (tone, isActive, hovered) {
      case (_, true, _):
        return DSButtonColors(fill: DS.Color.goldTint, border: border, label: DS.Color.gold300)
      case (.danger, false, true):
        return DSButtonColors(fill: DS.Color.dangerBg, border: border, label: DS.Color.dangerText)
      case (.neutral, false, true):
        return DSButtonColors(fill: DS.Color.bgHover, border: border, label: DS.Color.gold300)
      case (_, false, false):
        return DSButtonColors(fill: rest, border: border, label: DS.Color.textSecondary)
      }
    }
  }
}

/// Pill chip (preset summary): bg chip · muted gold border → gold on hover.
struct DSChipButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    DSChipBody(configuration: configuration)
  }

  private struct DSChipBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovered = false

    var body: some View {
      configuration.label
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textPrimary)
        .padding(.horizontal, DS.Space.s3)
        .frame(height: DS.Size.buttonDialog)
        .background(Capsule().fill(DS.Color.bgChip))
        .overlay(Capsule().strokeBorder(hovered ? DS.Color.gold500 : DS.Color.borderGoldMuted, lineWidth: DS.Stroke.hairline))
        .contentShape(Capsule())
        .opacity(configuration.isPressed ? DS.Opacity.pressed : 1)
        .onHover { hovered = $0 }
        .animation(DS.Motion.quick, value: hovered)
    }
  }
}

/// Full-width row in a menu or popover; `isOn` marks the current choice.
struct DSMenuItemButtonStyle: ButtonStyle {
  var isOn = false

  func makeBody(configuration: Configuration) -> some View {
    DSMenuItemBody(configuration: configuration, isOn: isOn)
  }

  private struct DSMenuItemBody: View {
    let configuration: ButtonStyleConfiguration
    let isOn: Bool
    @State private var hovered = false

    var body: some View {
      configuration.label
        .foregroundStyle(isOn ? DS.Color.gold300 : DS.Color.textPrimary)
        .padding(.horizontal, DS.Space.s2)
        .frame(height: DS.Size.menuItem)
        .background(RoundedRectangle(cornerRadius: DS.Radius.sm).fill(hovered ? DS.Color.bgHover : .clear))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
  }
}

struct DSButtonColors {
  let fill: SwiftUI.Color
  let border: SwiftUI.Color
  let label: SwiftUI.Color
}

/// Shared chrome for all button styles: hover tracking, disabled dimming, press feedback.
private struct DSButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let size: DS.ButtonSize
  var square = false
  let colors: (_ hovered: Bool, _ pressed: Bool) -> DSButtonColors
  @Environment(\.isEnabled) private var isEnabled
  @State private var hovered = false

  var body: some View {
    let palette = colors(hovered && isEnabled, configuration.isPressed)
    let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
    configuration.label
      .dsText(size.text)
      .lineLimit(1)
      .foregroundStyle(palette.label)
      .padding(.horizontal, square ? 0 : size.paddingX)
      .frame(width: square ? size.height : nil, height: size.height)
      .background(shape.fill(palette.fill))
      .overlay(shape.strokeBorder(palette.border, lineWidth: DS.Stroke.hairline))
      .contentShape(shape)
      .opacity(isEnabled ? (configuration.isPressed ? DS.Opacity.pressed : 1) : DS.Opacity.disabled)
      .onHover { hovered = $0 }
      .animation(DS.Motion.quick, value: hovered)
  }
}

// MARK: - Containers

/// Inset well that holds a row of related buttons (bg.inset · border.default · radius.lg).
struct DSButtonGroup<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    HStack(spacing: DS.Space.s0_5) { content }
      .padding(DS.Size.buttonGroupInset)
      .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(DS.Color.bgInset))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
          .strokeBorder(DS.Color.borderDefault, lineWidth: DS.Stroke.hairline)
      )
  }
}

/// Raised card for modal dialogs (bg.raised · radius.2xl · padding space.6).
struct DSDialog<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.s3) { content }
      .padding(DS.Space.s6)
      .frame(width: DS.Size.dialogWidth)
      .background(RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous).fill(DS.Color.bgRaised))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
          .strokeBorder(DS.Color.borderGoldMuted, lineWidth: DS.Stroke.hairline)
      )
      .shadow(color: DS.Color.shadowDeep, radius: DS.Shadow.dialogRadius, y: DS.Shadow.dialogY)
  }
}

extension View {
  /// Presents `dialog` centred over this view on a scrim. Clicking the scrim or pressing Esc dismisses.
  func dsDialog<Dialog: View>(
    isPresented: Bool,
    onDismiss: @escaping () -> Void,
    @ViewBuilder dialog: () -> Dialog
  ) -> some View {
    overlay {
      if isPresented {
        ZStack {
          DS.Color.bgScrim
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
          dialog()
            .onExitCommand(perform: onDismiss)
        }
        .transition(.opacity)
      }
    }
    .animation(DS.Motion.quick, value: isPresented)
  }
}

// MARK: - Indicators

/// Pill badge: gold for savings, danger for "Not found".
struct DSBadge: View {
  enum Tone {
    case gold
    case danger
  }

  let text: String
  var tone: Tone = .gold

  var body: some View {
    Text(text)
      .dsText(DS.Typography.micro)
      .foregroundStyle(tone == .gold ? DS.Color.onGold : DS.Color.dangerText)
      .padding(.horizontal, DS.Space.s2)
      .padding(.vertical, DS.Space.s0_5)
      .background(Capsule().fill(tone == .gold ? DS.Color.gold500 : DS.Color.dangerBg))
  }
}

/// Thin pill progress bar (track progressTrack · fill gold.500).
struct DSProgressBar: View {
  /// 0…1; values outside are clamped.
  let value: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(DS.Color.progressTrack)
        Capsule()
          .fill(DS.Color.gold500)
          .frame(width: proxy.size.width * min(max(value, 0), 1))
      }
    }
    .frame(height: DS.Size.progressBar)
    .animation(.linear, value: value)
    .accessibilityElement()
    .accessibilityValue(Text("\(Int(value * 100)) percent"))
  }
}

/// Gold square checkbox used in selection mode.
struct DSCheckbox: View {
  let isOn: Bool
  var isEnabled = true
  let label: String
  let toggle: () -> Void

  var body: some View {
    Button(action: toggle) {
      ZStack {
        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
          .fill(isOn ? DS.Color.gold500 : .clear)
        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
          .strokeBorder(isOn ? DS.Color.gold500 : DS.Color.spanNormal, lineWidth: DS.Stroke.emphasis)
        if isOn {
          Image(systemName: "checkmark")
            .font(.system(size: DS.Size.glyphSmall, weight: .heavy))
            .foregroundStyle(DS.Color.onGold)
        }
      }
      .frame(width: DS.Size.checkbox, height: DS.Size.checkbox)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : DS.Opacity.unavailable)
    .accessibilityLabel(label)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}

/// SF Symbol sized and weighted like the canvas' 1.8–2.2 px stroke icons.
struct DSIcon: View {
  let systemName: String
  var size: CGFloat = DS.Size.glyph

  init(_ systemName: String, size: CGFloat = DS.Size.glyph) {
    self.systemName = systemName
    self.size = size
  }

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: size, weight: .medium))
  }
}
