import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settings = SettingsStore()
  let history = HistoryStore()
  let preferences = AppPreferences()
  lazy var queue: JobQueue = {
    let queue = JobQueue(settings: settings)
    queue.onJobFinished = { [history] job, result in
      history.record(output: result.output, originalBytes: job.originalBytes, outputBytes: result.bytes)
    }
    return queue
  }()
  lazy var actions = AppActions(queue: queue)
  private lazy var menuBar = MenuBarController(queue: queue, actions: actions)
  private lazy var dropZone = FloatingDropZoneController(actions: actions)

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Needed when launched as a bare executable (`swift run`) rather than from the .app bundle.
    NSApp.setActivationPolicy(.regular)
    applyPresence()
    NSApp.activate()
    preferences.onPresenceChange = { [weak self] in self?.applyPresence() }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    // Login Items can be changed in System Settings while the app is running.
    preferences.refreshLaunchAtLogin()
  }

  /// Files dropped on the Dock icon or opened via "Open With".
  func application(_ application: NSApplication, open urls: [URL]) {
    queue.enqueue(urls)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    preferences.presence.terminatesAfterLastWindowClosed
  }

  private func applyPresence() {
    let presence = preferences.presence
    menuBar.setVisible(presence.showInMenuBar)
    dropZone.setEnabled(presence.dropZoneWhileDragging)
    preferences.isDragMonitorAvailable = dropZone.isAvailable
    let policy: NSApplication.ActivationPolicy = presence.effectiveShowInDock ? .regular : .accessory
    if NSApp.activationPolicy() != policy {
      NSApp.setActivationPolicy(policy)
      // Switching policy deactivates the app; keep the window the user is toggling this from in front.
      NSApp.activate()
    }
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
        .environment(delegate.history)
        .environment(delegate.preferences)
        .modifier(AppActionsBridge(actions: delegate.actions))
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
        .environment(delegate.preferences)
        .modifier(AppActionsBridge(actions: delegate.actions))
        .frame(width: DS.Size.settingsWindowWidth, height: DS.Size.settingsWindowHeight)
    }
  }
}

enum WindowID {
  static let main = "main"
  static let editor = "editor"
}
