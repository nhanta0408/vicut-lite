/// Where the app shows up: menu bar, Dock, and the drag-time drop zone.
public struct AppPresence: Equatable, Sendable {
  public var showInMenuBar: Bool
  public var showInDock: Bool
  public var dropZoneWhileDragging: Bool

  public static let `default` = AppPresence(showInMenuBar: true, showInDock: true, dropZoneWhileDragging: true)

  public init(showInMenuBar: Bool, showInDock: Bool, dropZoneWhileDragging: Bool) {
    self.showInMenuBar = showInMenuBar
    self.showInDock = showInDock
    self.dropZoneWhileDragging = dropZoneWhileDragging
  }

  /// Without the menu bar icon the Dock is the only way back in, so it can't be hidden too.
  public var effectiveShowInDock: Bool {
    showInDock || !showInMenuBar
  }

  /// Quitting on the last window close would also remove the menu bar icon the user relies on.
  public var terminatesAfterLastWindowClosed: Bool {
    !showInMenuBar
  }

  /// Hiding the Dock is only offered while the menu bar icon is on.
  public var canHideDock: Bool {
    showInMenuBar
  }
}
