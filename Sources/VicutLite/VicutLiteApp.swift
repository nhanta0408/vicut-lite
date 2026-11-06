import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settings = SettingsStore()
  lazy var queue = JobQueue(settings: settings)

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Needed when launched as a bare executable (`swift run`) rather than from the .app bundle.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Files dropped on the Dock icon or opened via "Open With".
  func application(_ application: NSApplication, open urls: [URL]) {
    queue.enqueue(urls)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@main
struct VicutLiteApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    Window("ViCut Lite", id: WindowID.main) {
      MainView()
        .environment(delegate.queue)
        .environment(delegate.settings)
    }
    .defaultSize(DS.Size.queueWindow)
    .windowResizability(.contentMinSize)
    // MainView draws its own 48 pt title bar (QueueTitleBar).
    .windowStyle(.hiddenTitleBar)

    WindowGroup("Editor", id: WindowID.editor, for: URL.self) { $url in
      if let url {
        EditorView(url: url)
          .environment(delegate.queue)
          .environment(delegate.settings)
      }
    }
    .defaultSize(width: 1000, height: 720)

    Settings {
      SettingsView()
        .environment(delegate.settings)
    }
  }
}

enum WindowID {
  static let main = "main"
  static let editor = "editor"
}
