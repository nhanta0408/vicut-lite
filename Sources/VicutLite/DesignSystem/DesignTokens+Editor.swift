import SwiftUI

// Editor-specific tokens from the "Editor" artboard. Kept in a separate file so the base token
// file stays conflict-free while windows are redesigned in parallel; values are additive only.

extension DS.Color {
  /// Menu / popover / dialog border and the stage chip (canvas: `border.gold` alt #3A3226).
  static let borderGoldSoft = SwiftUI.Color(hex: 0x3A3226)
  /// Info toast and chip fill on the video stage.
  static let bgToast = SwiftUI.Color(hex: 0x1A1813)
  /// Error toast border.
  static let editorDangerBorder = SwiftUI.Color(hex: 0x6B2F22)
  /// Ring around the round play button.
  static let goldHalo = SwiftUI.Color(hex: 0xE4B53F).opacity(0.15)
  /// Count pill inside the Spans toggle.
  static let bgPill = SwiftUI.Color(hex: 0x26231E)

  // Timeline spans
  /// Normal span filmstrip: frame and sprocket gap.
  static let spanFilmFrame = SwiftUI.Color(hex: 0x1F1C17)
  static let spanFilmGap = SwiftUI.Color(hex: 0x17150F)
  /// Cut span hatch: danger stripes over a dark base.
  static let spanCutStripe = SwiftUI.Color(hex: 0xE5684D).opacity(0.55)
  static let spanCutBase = SwiftUI.Color(hex: 0x24120E)
  /// "CUT" tag on the hatch.
  static let spanCutLabel = SwiftUI.Color(hex: 0xFFD9CF)
  /// 2× span fill.
  static let spanSpeedFill = SwiftUI.Color(hex: 0x6E5520)
  /// Real thumbnails sit under normal spans; dimmed so the playhead and ring stay readable.
  static let spanThumbOpacity = 0.55
  /// Playhead line and head; pure white so it reads on every span fill.
  static let playhead = SwiftUI.Color.white
  /// Menu / dialog drop shadow.
  static let shadow = SwiftUI.Color.black.opacity(0.55)
}

extension DS.Space {
  /// Gap inside dialogs, title bar items (canvas: 14).
  static let s3_5: CGFloat = 14
}

extension DS.Radius {
  /// Timeline span and stage chip corners.
  static let span: CGFloat = 6
  /// Primary / ghost buttons at 38 pt.
  static let button: CGFloat = 11
}

extension DS.Size {
  /// Transport + export bar height.
  static let transportBar: CGFloat = 60
  /// Round play / pause button.
  static let playButton: CGFloat = 42
  /// Ring width around the play button.
  static let playHalo: CGFloat = 4
  /// Export / Cancel buttons.
  static let footerButton: CGFloat = 38
  /// Ghost icon buttons in the timeline header.
  static let editorIconButton: CGFloat = 30
  /// Timeline header row.
  static let timelineHeader: CGFloat = 32
  /// Span track height.
  static let timelineTrack: CGFloat = 60
  /// Ruler labels under the track.
  static let timelineRuler: CGFloat = 14
  /// Overview bar under the ruler when zoomed.
  static let timelineOverview: CGFloat = 12
  /// Playhead overhang above and below the track.
  static let playheadOverhang: CGFloat = 6
  static let playheadHead: CGFloat = 12
  static let playheadWidth: CGFloat = 2
  /// Snap guide line.
  static let snapGuideWidth: CGFloat = 2
  /// Gutter on each side of a span so neighbours read as separate blocks.
  static let spanGutter: CGFloat = 1
  /// Selected span ring and glow.
  static let selectionRing: CGFloat = 2
  static let selectionGlow: CGFloat = 5
  /// Filmstrip frame and gap widths for normal spans.
  static let filmFrame: CGFloat = 26
  static let filmGap: CGFloat = 2
  /// Cut hatch stripe and gap widths (45°).
  static let hatchStripe: CGFloat = 5
  static let hatchGap: CGFloat = 6
  /// Square swatch next to span names.
  static let swatch: CGFloat = 10
  /// Menu items.
  static let editorMenuItem: CGFloat = 34
  static let menuWidth: CGFloat = 240
  /// Menu / dialog shadow blur and offset.
  static let shadowRadius: CGFloat = 20
  static let shadowY: CGFloat = 16
  /// Icon glyph sizes inside buttons.
  static let icon: CGFloat = 15
  static let iconSmall: CGFloat = 13
  /// Spans panel width (floating or docked), reserved for the panel seam.
  static let spansPanel: CGFloat = 360
  /// Editor window minimum.
  static let editorMinWidth: CGFloat = 820
  static let editorMinHeight: CGFloat = 560
  /// Export choice popover.
  static let exportPopover: CGFloat = 320
  static let exportChoiceIcon: CGFloat = 26
  /// Zoom label column, wide enough for "12:34.5".
  static let zoomLabel: CGFloat = 56
}
