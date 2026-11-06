import AppKit
import SwiftUI
import VicutCore

/// The status item: a template ViCut logo that opens a popover and also accepts dropped videos.
///
/// AppKit rather than `MenuBarExtra`, because a SwiftUI menu bar extra can't be a drop target.
@MainActor
final class MenuBarController: NSObject {
  private let queue: JobQueue
  private let actions: AppActions
  private var statusItem: NSStatusItem?
  private lazy var popover = makePopover()

  init(queue: JobQueue, actions: AppActions) {
    self.queue = queue
    self.actions = actions
  }

  func setVisible(_ visible: Bool) {
    if visible {
      if statusItem == nil { install() }
    } else if let statusItem {
      popover.performClose(nil)
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  private func install() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    guard let button = item.button else { return }
    button.image = Self.templateLogo()
    button.imagePosition = .imageOnly
    button.toolTip = "ViCut Lite: drop videos here to compress"
    button.setAccessibilityLabel("ViCut Lite")
    button.target = self
    button.action = #selector(togglePopover(_:))
    // NSStatusBarButton can't be subclassed into a drop target, but its window forwards
    // dragging-destination messages to the window delegate.
    button.window?.registerForDraggedTypes([.fileURL])
    button.window?.delegate = self
    statusItem = item
  }

  @objc private func togglePopover(_ sender: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(sender)
    } else {
      // Transient popovers only close on outside clicks while their app is active.
      NSApp.activate()
      popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
  }

  private func makePopover() -> NSPopover {
    let content = MenuBarPanelView(
      onDrop: { [weak self] urls, action in
        guard let self else { return false }
        return self.actions.handle(urls, action: action, announce: false)
      },
      onOpenApp: { [weak self] in
        self?.popover.performClose(nil)
        self?.actions.showMainWindow()
      },
      onOpenSettings: { [weak self] in
        self?.popover.performClose(nil)
        self?.actions.showSettings()
      }
    )
    .environment(queue)
    let controller = NSHostingController(rootView: content)
    controller.sizingOptions = .preferredContentSize
    let popover = NSPopover()
    popover.contentViewController = controller
    popover.behavior = .transient
    popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    popover.appearance = NSAppearance(named: .darkAqua)
    return popover
  }

  /// BrandMark's V as a template image, so macOS tints it for light / dark menu bars.
  private static func templateLogo() -> NSImage? {
    let mark = BrandMark(showsTile: false)
      .frame(width: DS.Size.statusItemMarkCanvas, height: DS.Size.statusItemMarkCanvas)
      .frame(width: DS.Size.statusItemGlyph, height: DS.Size.statusItemGlyph)
      .clipped()
    let renderer = ImageRenderer(content: mark)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
    guard let image = renderer.nsImage else { return nil }
    image.isTemplate = true
    image.accessibilityDescription = "ViCut Lite"
    return image
  }

  private static func videos(in info: NSDraggingInfo) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    return VideoFiles.supported(in: urls)
  }
}

extension MenuBarController: NSWindowDelegate, NSDraggingDestination {
  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard !Self.videos(in: sender).isEmpty else { return [] }
    statusItem?.button?.highlight(true)
    return .copy
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    statusItem?.button?.highlight(false)
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    statusItem?.button?.highlight(false)
    let action: DropAction = NSEvent.modifierFlags.contains(.option) ? .edit : .compress
    return actions.handle(Self.videos(in: sender), action: action)
  }
}
