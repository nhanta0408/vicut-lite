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
    /// Hover of solid danger buttons.
    static let danger400 = SwiftUI.Color(hex: 0xF07A60)

    // Component-specific values from the Queue artboard
    /// Window outline.
    static let borderWindow = SwiftUI.Color(hex: 0x2A2722)
    /// Queue row on hover.
    static let bgCardHover = SwiftUI.Color(hex: 0x181714)
    /// Queue row border on hover.
    static let borderCardHover = SwiftUI.Color(hex: 0x332E25)
    /// Thumbnail well behind a video frame.
    static let bgThumb = SwiftUI.Color(hex: 0x1C1A16)
    /// Thumbnail well border.
    static let borderThumb = SwiftUI.Color(hex: 0x2A2620)
    /// Darkens a thumbnail under the progress %.
    static let bgThumbOverlay = SwiftUI.Color.black.opacity(0.55)
    /// Duration chip on a thumbnail.
    static let bgThumbChip = SwiftUI.Color.black.opacity(0.75)
    /// Progress bar track.
    static let progressTrack = SwiftUI.Color(hex: 0x24211C)
    /// Drop zone fill at rest (gold 4 %) and while a drag hovers it.
    static let goldWash = SwiftUI.Color(hex: 0xE4B53F).opacity(0.04)
    static let goldWashActive = SwiftUI.Color(hex: 0xE4B53F).opacity(0.10)
    /// Preset chip, dialog border (muted gold).
    static let borderGoldMuted = SwiftUI.Color(hex: 0x3A3226)
    /// Preset chip fill.
    static let bgChip = SwiftUI.Color(hex: 0x161511)
    /// Selection bar replacing the footer in select mode.
    static let bgSelectionBar = SwiftUI.Color(hex: 0x15130F)
    /// Glow ring and drop shadow under the main primary button.
    static let goldRing = SwiftUI.Color(hex: 0xF5D27A).opacity(0.4)
    static let goldGlow = SwiftUI.Color(hex: 0xE4B53F).opacity(0.18)
    /// Shadow under dialogs and popovers.
    static let shadowDeep = SwiftUI.Color.black.opacity(0.6)
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
    /// Body-size emphasis: dialog / footer button labels, selection count.
    static let bodyBold = TextStyle(size: 13, bold: true, lineHeight: 1.5, tracking: 0, uppercase: false)
    /// Duration chip on thumbnails.
    static let tiny = TextStyle(size: 10, bold: true, lineHeight: 1.2, tracking: 0, uppercase: false)
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
    /// Title-bar icon buttons.
    static let iconButtonSmall: CGFloat = 32
    /// Icon buttons inside button groups.
    static let iconButton: CGFloat = 36
    /// Standalone row / footer buttons.
    static let buttonLarge: CGFloat = 40
    /// Dialog buttons and the preset chip.
    static let buttonDialog: CGFloat = 38
    /// Padding between a button group's well and its buttons.
    static let buttonGroupInset: CGFloat = 3
    /// Queue drop zone height.
    static let dropZone: CGFloat = 52
    /// Footer and selection bar height.
    static let footer: CGFloat = 64
    /// Queue row thumbnail (square).
    static let thumbnail: CGFloat = 76
    /// Progress bar thickness.
    static let progressBar: CGFloat = 6
    /// Selection checkbox.
    static let checkbox: CGFloat = 24
    /// Confirmation dialog width.
    static let dialogWidth: CGFloat = 420
    /// Glyph sizes for SF Symbols.
    static let glyphSmall: CGFloat = 13
    static let glyph: CGFloat = 16
    static let glyphLarge: CGFloat = 18
    /// Illustration glyph in empty states.
    static let emptyStateGlyph: CGFloat = 40
    /// Brand mark in the title bar.
    static let brandMark: CGFloat = 22
    /// Hairline divider between title-bar groups.
    static let dividerHeight: CGFloat = 18
    /// Space reserved for the macOS traffic-light buttons in a hidden title bar.
    static let trafficLights: CGFloat = 78
    /// Tallest file list inside a dialog before it scrolls.
    static let dialogListMax: CGFloat = 180
    /// Menu / popover item height.
    static let menuItem: CGFloat = 32
    /// ffmpeg log popover.
    static let logPopover = CGSize(width: 520, height: 260)
    /// Compression preset popover width.
    static let presetPopoverWidth: CGFloat = 260
    /// Queue window default and minimum size.
    static let queueWindow = CGSize(width: 760, height: 680)
    static let queueWindowMin = CGSize(width: 600, height: 460)
  }

  /// Stroke widths.
  enum Stroke {
    static let hairline: CGFloat = 1
    /// Drop zone dash, checkbox outline.
    static let emphasis: CGFloat = 1.5
    static let dash: [CGFloat] = [6, 4]
  }

  /// Opacity for de-emphasised states.
  enum Opacity {
    /// Queued rows wait their turn.
    static let queued: Double = 0.72
    static let disabled: Double = 0.4
    /// Checkbox of a row that cannot be selected.
    static let unavailable: Double = 0.35
    /// Feedback while a button is held down.
    static let pressed: Double = 0.85
  }

  enum Shadow {
    static let dialogRadius: CGFloat = 30
    static let dialogY: CGFloat = 12
    static let glowRadius: CGFloat = 9
    static let glowY: CGFloat = 3
  }

  enum Motion {
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
