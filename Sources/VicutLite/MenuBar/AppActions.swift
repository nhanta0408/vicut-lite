import AppKit
import SwiftUI
import VicutCore

/// App-wide actions reachable from AppKit (status item, floating panel), which have no SwiftUI
/// `openWindow` / `openSettings` of their own. The SwiftUI scenes hand theirs over on appear.
@MainActor
final class AppActions {
  var openWindow: OpenWindowAction?
  var openSettings: OpenSettingsAction?
  /// Drops outside any window (floating zone, status item) report here so the user sees progress.
  var onCompressStarted: (([Job]) -> Void)?
  private let queue: JobQueue

  init(queue: JobQueue) {
    self.queue = queue
  }

  /// Compress (or, with `.edit`, open the editor for) the supported videos among `urls`.
  /// `announce` = false when the drop target already lists the jobs (the menu bar popover).
  @discardableResult
  func handle(_ urls: [URL], action: DropAction, announce: Bool = true) -> Bool {
    let videos = VideoFiles.supported(in: urls)
    guard !videos.isEmpty else { return false }
    switch action {
    case .compress:
      let jobs = queue.enqueue(videos)
      if announce, !jobs.isEmpty { onCompressStarted?(jobs) }
    case .edit:
      bringToFront()
      videos.forEach { openEditor($0) }
    }
    return true
  }

  func showMainWindow() {
    bringToFront()
    openWindow?(id: WindowID.main)
    // Activation is only a request since macOS 14; if another app keeps focus, still raise the window.
    let window = NSApp.windows.first { $0.identifier?.rawValue == WindowID.main }
      ?? NSApp.windows.first { $0.canBecomeMain }
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
  }

  func showSettings() {
    bringToFront()
    if let openSettings {
      openSettings()
    } else {
      showMainWindow()
    }
  }

  private func openEditor(_ url: URL) {
    if let openWindow {
      openWindow(id: WindowID.editor, value: url)
    } else {
      // Only before any SwiftUI window has appeared; the queue is the next best place for the file.
      queue.enqueue([url])
    }
  }

  /// Without a Dock icon the app is never active on its own, so new windows would open behind others.
  private func bringToFront() {
    NSApp.activate()
  }
}

/// Hands the scene's window actions to `AppActions` so AppKit code can open windows later.
struct AppActionsBridge: ViewModifier {
  let actions: AppActions
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings

  func body(content: Content) -> some View {
    content.onAppear {
      actions.openWindow = openWindow
      actions.openSettings = openSettings
    }
  }
}

/// Finder / pasteboard helpers shared by the queue rows and the menu bar list.
enum FileActions {
  static func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  /// Pasting a file URL into a GitHub comment uploads it.
  static func copy(_ url: URL) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
  }
}
