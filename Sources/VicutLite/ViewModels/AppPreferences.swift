import Foundation
import Observation
import ServiceManagement
import VicutCore

/// Menu bar / Dock / drop zone preferences. Kept apart from `SettingsStore` so the saved
/// `CompressSettings` JSON keeps its shape and older builds still decode it.
@MainActor
@Observable
final class AppPreferences {
  private enum Key {
    static let showInMenuBar = "showInMenuBar"
    static let showInDock = "showInDock"
    static let dropZoneWhileDragging = "dropZoneWhileDragging"
  }

  var showInMenuBar: Bool {
    didSet {
      // Never leave the app with neither a Dock icon nor a menu bar icon.
      if !showInMenuBar { showInDock = true }
      persist(showInMenuBar, Key.showInMenuBar)
    }
  }

  var showInDock: Bool {
    didSet { persist(showInDock, Key.showInDock) }
  }

  var dropZoneWhileDragging: Bool {
    didSet { persist(dropZoneWhileDragging, Key.dropZoneWhileDragging) }
  }

  /// False when macOS refused the system-wide drag monitor; Settings explains it instead of the zone silently missing.
  var isDragMonitorAvailable = true

  /// Mirrors `SMAppService.mainApp`; re-read after every change because the user can also flip it in System Settings.
  private(set) var launchAtLogin = false
  private(set) var launchAtLoginNote: String?

  /// Fires after any presence change so the app delegate can apply it to AppKit.
  @ObservationIgnored var onPresenceChange: (() -> Void)?
  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let fallback = AppPresence.default
    showInMenuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? fallback.showInMenuBar
    showInDock = defaults.object(forKey: Key.showInDock) as? Bool ?? fallback.showInDock
    dropZoneWhileDragging = defaults.object(forKey: Key.dropZoneWhileDragging) as? Bool ?? fallback.dropZoneWhileDragging
    refreshLaunchAtLogin()
  }

  var presence: AppPresence {
    AppPresence(showInMenuBar: showInMenuBar, showInDock: showInDock, dropZoneWhileDragging: dropZoneWhileDragging)
  }

  // MARK: Launch at login

  /// A bare `swift run` binary has no bundle for Login Items to point at.
  var canLaunchAtLogin: Bool {
    Bundle.main.bundleURL.pathExtension == "app"
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      refreshLaunchAtLogin()
    } catch {
      refreshLaunchAtLogin()
      launchAtLoginNote = "macOS refused: \(error.localizedDescription)"
    }
  }

  func refreshLaunchAtLogin() {
    switch SMAppService.mainApp.status {
    case .enabled:
      launchAtLogin = true
      launchAtLoginNote = nil
    case .requiresApproval:
      launchAtLogin = false
      launchAtLoginNote = "Allow ViCut Lite in System Settings → General → Login Items."
    case .notRegistered, .notFound:
      launchAtLogin = false
      launchAtLoginNote = nil
    @unknown default:
      launchAtLogin = false
      launchAtLoginNote = nil
    }
  }

  private func persist(_ value: Bool, _ key: String) {
    defaults.set(value, forKey: key)
    onPresenceChange?()
  }
}
