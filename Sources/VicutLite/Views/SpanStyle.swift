import SwiftUI
import VicutCore

/// How a span type looks wherever it's listed: timeline, header, menus, dialogs, Spans panel.
extension SegmentAction {
  var swatch: Color {
    switch self {
    case .keep: DS.Color.spanNormal
    case .cut: DS.Color.danger500
    case .speed: DS.Color.gold500
    }
  }

  var titleColor: Color {
    switch self {
    case .keep: DS.Color.textPrimary
    case .cut: DS.Color.dangerText
    case .speed: DS.Color.gold300
    }
  }

  /// Short tag drawn on the timeline block; normal spans carry none.
  var tag: String? {
    switch self {
    case .keep: nil
    case .cut: "CUT"
    case .speed(let factor): Formatters.speed(factor)
    }
  }

  /// Choices offered in span-type menus: the canvas lists Normal, Cut and 2×; a 4× / 8× span
  /// (set with the number keys) is added so its current type still shows as checked.
  static func menuChoices(current: SegmentAction?) -> [SegmentAction] {
    var choices: [SegmentAction] = [.keep, .cut, .speed(2), .speed(4)]
    if let current, !choices.contains(current) {
      choices.append(current)
    }
    return choices
  }
}
