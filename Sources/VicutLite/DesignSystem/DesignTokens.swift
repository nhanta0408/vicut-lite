import SwiftUI

// Design tokens from the "ViCut Lite Redesign" canvas, artboard "Design system":
// https://claude.ai/artifact/AaJW5EaVvsUj2ggtGSUwoW
// Black & gold, one typeface (Menlo), 4 pt spacing grid. Names mirror the canvas tokens
// (`bg.app` → `DS.Color.bgApp`) so a design review can be checked against code 1:1.
// Change values here only; views must not use raw hex, sizes or fonts.

enum DS {}

// MARK: - 01 · Color

extension DS {
  enum Color {
    // Surface
    /// Window body, Editor, page backgrounds.
    static let bgApp = SwiftUI.Color(hex: 0x0E0E0F)
    /// Title bar, footer, side panels, tab bar.
    static let bgChrome = SwiftUI.Color(hex: 0x111111)
    /// Queue row, history item, list cards.
    static let bgCard = SwiftUI.Color(hex: 0x131312)
    /// Button groups, inputs, segmented tracks, timeline well.
    static let bgInset = SwiftUI.Color(hex: 0x0B0B0B)
    /// Menus, popovers, dialogs.
    static let bgRaised = SwiftUI.Color(hex: 0x161513)
    /// Video preview stage.
    static let bgStage = SwiftUI.Color(hex: 0x080808)
    /// Behind dialogs and the side tab bar.
    static let bgScrim = SwiftUI.Color.black.opacity(0.6)
    /// Hover on ghost / icon buttons, menu items.
    static let bgHover = SwiftUI.Color(hex: 0x221F1A)

    // Border
    /// Dividers, row default border, section lines.
    static let borderSubtle = SwiftUI.Color(hex: 0x1F1D19)
    /// Button groups, inputs, inset tracks.
    static let borderDefault = SwiftUI.Color(hex: 0x26231E)
    /// Ghost buttons (Cancel, Settings).
    static let borderStrong = SwiftUI.Color(hex: 0x2E2A23)
    /// Drop zone dash, selected panels, preset chip.
    static let borderGold = SwiftUI.Color(hex: 0x4A3F27)

    // Text
    /// File names, values, headings.
    static let textPrimary = SwiftUI.Color(hex: 0xF3EEE3)
    /// Button labels, icons at rest.
    static let textSecondary = SwiftUI.Color(hex: 0xCFC8BA)
    /// Meta, hints, section labels.
    static let textMuted = SwiftUI.Color(hex: 0xA8A195)
    /// Timeline ticks, separators, tiny captions.
    static let textFaint = SwiftUI.Color(hex: 0x8C857A)

    // Brand · gold
    /// Primary buttons, badges, progress, focus, selection.
    static let gold500 = SwiftUI.Color(hex: 0xE4B53F)
    /// Hover of primary buttons.
    static let gold400 = SwiftUI.Color(hex: 0xF0C552)
    /// Gold text on dark, active labels, highlights.
    static let gold300 = SwiftUI.Color(hex: 0xF5D27A)
    /// Icon gradient end.
    static let gold700 = SwiftUI.Color(hex: 0x9E7020)
    /// Active toggle / pin / tab background.
    static let goldTint = SwiftUI.Color(hex: 0xE4B53F).opacity(0.12)
    /// Text and icons placed on gold.
    static let onGold = SwiftUI.Color(hex: 0x0E0E0F)

    // Status
    /// Delete originals, Cut span, destructive confirm.
    static let danger500 = SwiftUI.Color(hex: 0xE5684D)
    /// Danger text, "Not found" badge, cut labels.
    static let dangerText = SwiftUI.Color(hex: 0xF09A84)
    /// Danger hover, error toast background.
    static let dangerBg = SwiftUI.Color(hex: 0x2A1410)
    /// Normal span swatch in timeline / list.
    static let spanNormal = SwiftUI.Color(hex: 0x5E584D)
  }
}

// MARK: - 02 · Typography

extension DS {
  /// One text style = font + line height + tracking + case, applied with `.dsText(_:)`.
  struct TextStyle: Sendable {
    let size: CGFloat
    let bold: Bool
    /// Line height as a multiple of the font size (CSS `line-height`).
    let lineHeight: CGFloat
    let tracking: CGFloat
    let uppercase: Bool

    /// Menlo ships Regular + Bold only, so weight is 400 or 700.
    var font: Font {
      .custom(bold ? DS.Typography.familyBold : DS.Typography.family, size: size)
    }

    /// SwiftUI adds `lineSpacing` between lines on top of the font's natural height.
    var lineSpacing: CGFloat {
      max(0, (lineHeight - 1) * size)
    }
  }

  enum Typography {
    static let family = "Menlo-Regular"
    static let familyBold = "Menlo-Bold"

    /// Marketing / design docs only.
    static let display = TextStyle(size: 34, bold: true, lineHeight: 1.2, tracking: 0, uppercase: false)
    /// Full-window page titles (History, Settings).
    static let page = TextStyle(size: 22, bold: true, lineHeight: 1.3, tracking: 0, uppercase: false)
    /// Dialog titles, output length number.
    static let title = TextStyle(size: 18, bold: true, lineHeight: 1.3, tracking: 0, uppercase: false)
    /// Brand in title bar, panel titles, progress % on thumbnail.
    static let heading = TextStyle(size: 15, bold: true, lineHeight: 1.3, tracking: 0.2, uppercase: false)
    /// Original file name in queue row.
    static let bodyStrong = TextStyle(size: 14, bold: true, lineHeight: 1.4, tracking: 0, uppercase: false)
    /// Default UI text, dialog body, menu items, buttons.
    static let body = TextStyle(size: 13, bold: false, lineHeight: 1.5, tracking: 0, uppercase: false)
    /// Button labels, sizes, span times, inputs.
    static let label = TextStyle(size: 12.5, bold: true, lineHeight: 1.4, tracking: 0, uppercase: false)
    /// Meta lines, output name, hints, toasts.
    static let caption = TextStyle(size: 12, bold: false, lineHeight: 1.5, tracking: 0, uppercase: false)
    /// Section labels in Settings, menus, legends.
    static let overline = TextStyle(size: 11.5, bold: true, lineHeight: 1.2, tracking: 1.2, uppercase: true)
    /// Badges on gold, duration chip. Timeline ticks use `microRegular`.
    static let micro = TextStyle(size: 11, bold: true, lineHeight: 1.2, tracking: 0, uppercase: false)
    static let microRegular = TextStyle(size: 11, bold: false, lineHeight: 1.2, tracking: 0, uppercase: false)
  }
}

extension View {
  /// Applies a design-system text style. Color stays separate (`.foregroundStyle(DS.Color.…)`).
  func dsText(_ style: DS.TextStyle) -> some View {
    font(style.font)
      .tracking(style.tracking)
      .lineSpacing(style.lineSpacing)
      .textCase(style.uppercase ? .uppercase : nil)
  }
}

// MARK: - 03 · Spacing (4 pt base: use only these steps for padding and gap)

extension DS {
  enum Space {
    /// Gap inside segmented controls / button groups.
    static let s0_5: CGFloat = 2
    /// Icon ↔ tiny label, menu item gap, list stack in panels.
    static let s1: CGFloat = 4
    /// Row-to-row gap, icon ↔ label in buttons, button ↔ button.
    static let s2: CGFloat = 8
    /// Row inner padding, chip padding-x, toolbar gap.
    static let s3: CGFloat = 12
    /// Window side padding, title bar / footer padding-x, cards.
    static let s4: CGFloat = 16
    /// Full-window page padding, settings group gap.
    static let s5: CGFloat = 20
    /// Dialog padding, section gap in panels.
    static let s6: CGFloat = 24
    /// Large section gap.
    static let s8: CGFloat = 32
  }
}

// MARK: - 04 · Radius & size

extension DS {
  enum Radius {
    /// Duration chip, swatches, small bars.
    static let xs: CGFloat = 4
    /// Inputs, segmented items, small buttons (28 pt).
    static let sm: CGFloat = 7
    /// Icon buttons 36 pt, menu items.
    static let md: CGFloat = 9
    /// Buttons 40 pt, drop zone, button groups, menus.
    static let lg: CGFloat = 12
    /// Queue row, window, floating panels.
    static let xl: CGFloat = 14
    /// Dialogs.
    static let xxl: CGFloat = 16
    /// Badges, preset chip, progress bar, toggle.
    static let pill: CGFloat = 999
  }

  enum Size {
    /// Smallest hit target.
    static let hitMin: CGFloat = 28
    /// Smallest primary button height.
    static let primaryMin: CGFloat = 36
    /// Title bar height in every window.
    static let titleBar: CGFloat = 48
  }
}

// MARK: - History page (additive)

extension DS.Color {
  /// Outline of the "Not found" badge.
  static let dangerBorder = SwiftUI.Color(hex: 0x5A2A20)
}

extension DS.Space {
  /// History item inner padding (canvas: "padding 10").
  static let s2_5: CGFloat = 10
  /// Badge horizontal padding (canvas: "2 × 7").
  static let badgeX: CGFloat = 7
}

extension DS.Size {
  /// Borders and dividers.
  static let hairline: CGFloat = 1
  /// Small icon button (Show in Finder, title-bar buttons).
  static let iconButtonSm: CGFloat = 32
  /// Glyph inside a small icon button.
  static let iconGlyph: CGFloat = 16
  /// Glyph above an empty-state message.
  static let emptyGlyph: CGFloat = 32
}

extension DS {
  enum Opacity {
    /// Rows whose file is gone (History "Not found").
    static let unavailable: Double = 0.6
  }
}

// MARK: - Settings page (additive)

extension DS.Space {
  /// Inset between a segmented track and its items (canvas: "padding 3 · gap 3").
  static let s0_75: CGFloat = 3
  /// Icon ↔ label inside small ghost buttons (canvas: "icon gap 6").
  static let s1_5: CGFloat = 6
}

extension DS.Radius {
  /// Segmented track: item radius (`sm`) plus the track inset, so the corners stay concentric.
  static let track: CGFloat = sm + DS.Space.s0_75
}

extension DS.Size {
  /// Settings row minimum height.
  static let settingsRow: CGFloat = 52
  /// Item height inside a segmented control.
  static let segmentItem: CGFloat = 30
  /// Segmented control with four options (Target size).
  static let segmentWide: CGFloat = 340
  /// Segmented control with three options.
  static let segmentNarrow: CGFloat = 260
  /// Single-line text input height.
  static let inputHeight: CGFloat = 34
  /// Short text input (file name suffix).
  static let inputShort: CGFloat = 140
  /// Switch track.
  static let toggleWidth: CGFloat = 44
  static let toggleHeight: CGFloat = 26
  /// Switch knob: track height minus the inset on both sides.
  static let toggleKnob: CGFloat = toggleHeight - 2 * DS.Space.s0_75
  /// Glyph inside a text ghost button (Restore defaults).
  static let glyphSm: CGFloat = 14
  /// Inline arrow in captions (output name preview).
  static let glyphXs: CGFloat = 12
  /// Standalone Settings window (⌘,): fits the widest row without wrapping.
  static let settingsWindowWidth: CGFloat = 600
  static let settingsWindowHeight: CGFloat = 560
}

extension DS {
  enum Motion {
    /// Toggle knob and other small state flips.
    static let quick = Animation.easeOut(duration: 0.15)
  }
}

// MARK: - Helpers

extension SwiftUI.Color {
  /// `0xRRGGBB` in sRGB, matching the hex values on the canvas.
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: opacity
    )
  }
}
