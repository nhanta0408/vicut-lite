import AppKit
import Observation
import SwiftUI
import VicutCore

/// Clop-style drop zone: when a video drag starts in any app, a small panel slides in at the
/// bottom-right of that screen; dropping on it compresses (⌥: opens the editor).
///
/// Detection uses a global `leftMouseDragged` monitor plus the drag pasteboard's change count.
/// Global monitors for mouse events need no Accessibility or Input Monitoring permission (only
/// key events do); if macOS still refuses the monitor, `isAvailable` turns false and nothing shows.
@MainActor
final class FloatingDropZoneController {
  private let actions: AppActions
  private let model = FloatingDropZoneModel()
  private var monitor: Any?
  private var detector = DragSessionDetector(changeCount: NSPasteboard(name: .drag).changeCount)
  private var panel: FloatingDropZonePanel?
  private var pollTask: Task<Void, Never>?
  /// Bumped on every show / hide so a finishing hide animation can't order out a newer show.
  private var generation = 0
  private(set) var isAvailable = true

  /// Fast enough for the ⌥ hint to feel live, cheap enough to run for a whole drag.
  private static let pollInterval = Duration.milliseconds(80)
  /// The drop message can arrive just after the button-up we poll for; give it time to land.
  private static let releaseGrace = Duration.milliseconds(250)

  init(actions: AppActions) {
    self.actions = actions
  }

  func setEnabled(_ enabled: Bool) {
    if enabled {
      guard monitor == nil else { return }
      monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
        MainActor.assumeIsolated { self?.mouseDragged() }
      }
      isAvailable = monitor != nil
    } else {
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      hide(animated: false)
    }
  }

  // MARK: Detection

  private func mouseDragged() {
    guard panel?.isVisible != true else { return }
    let pasteboard = NSPasteboard(name: .drag)
    let videos = detector.videosForNewDrag(changeCount: pasteboard.changeCount) {
      guard let types = pasteboard.types, !types.isEmpty else { return nil }
      let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
      return pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }
    if videos != nil { show() }
  }

  /// Polled, not event-driven: the drag belongs to another app, so this one gets no mouse-up
  /// or flagsChanged events, but the global button and modifier state is always readable.
  private func trackDrag() {
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        self.model.opensEditor = NSEvent.modifierFlags.contains(.option)
        if NSEvent.pressedMouseButtons & 1 == 0 {
          try? await Task.sleep(for: Self.releaseGrace)
          guard !Task.isCancelled else { return }
          self.hide(animated: true)
          return
        }
        try? await Task.sleep(for: Self.pollInterval)
      }
    }
  }

  // MARK: Panel

  private func show() {
    let panel = panel ?? makePanel()
    self.panel = panel
    generation += 1
    model.isTargeted = false
    model.opensEditor = NSEvent.modifierFlags.contains(.option)

    let screens = NSScreen.screens
    guard let index = DropZonePlacement.screenIndex(containing: NSEvent.mouseLocation, screens: screens.map(\.frame))
    else { return }
    let target = DropZonePlacement.frame(
      size: DS.Size.floatingDropZone,
      in: screens[index].visibleFrame,
      margin: DS.Space.floatingDropZoneMargin
    )
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    panel.setFrame(reduceMotion ? target : DropZonePlacement.slidFrame(target, by: DS.Motion.floatingDropZoneSlide), display: false)
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = DS.Motion.floatingDropZoneDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
      panel.animator().setFrame(target, display: true)
    }
    trackDrag()
  }

  private func hide(animated: Bool) {
    pollTask?.cancel()
    pollTask = nil
    guard let panel, panel.isVisible else { return }
    generation += 1
    let hiding = generation
    guard animated else {
      panel.orderOut(nil)
      return
    }
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let end = reduceMotion ? panel.frame : DropZonePlacement.slidFrame(panel.frame, by: DS.Motion.floatingDropZoneSlide)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = DS.Motion.floatingDropZoneDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().alphaValue = 0
      panel.animator().setFrame(end, display: true)
    } completionHandler: { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.generation == hiding else { return }
        self.panel?.orderOut(nil)
      }
    }
  }

  private func drop(_ urls: [URL]) -> Bool {
    let action: DropAction = NSEvent.modifierFlags.contains(.option) ? .edit : .compress
    let handled = actions.handle(urls, action: action)
    hide(animated: true)
    return handled
  }

  private func makePanel() -> FloatingDropZonePanel {
    let panel = FloatingDropZonePanel(
      contentRect: CGRect(origin: .zero, size: DS.Size.floatingDropZone),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    let root = FloatingDropZoneView(model: model) { [weak self] urls in
      self?.drop(urls) ?? false
    }
    panel.contentView = NSHostingView(rootView: root)
    return panel
  }
}

/// Never takes key or main status, so the app the user is dragging from keeps focus.
private final class FloatingDropZonePanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
@Observable
private final class FloatingDropZoneModel {
  var isTargeted = false
  var opensEditor = false
}

/// The panel's face: same gold dashed language as `DropZoneView`, on an opaque card because it
/// floats over other apps.
private struct FloatingDropZoneView: View {
  let model: FloatingDropZoneModel
  let onDrop: ([URL]) -> Bool

  private var title: String {
    if model.opensEditor { return "Release to edit" }
    return model.isTargeted ? "Release to compress" : "Drop to compress"
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
    VStack(spacing: DS.Space.s2) {
      DSIcon(model.opensEditor ? "scissors" : "square.and.arrow.down", size: DS.Size.emptyGlyph)
        .foregroundStyle(DS.Color.gold500)
      Text(title)
        .dsText(DS.Typography.heading)
        .foregroundStyle(model.isTargeted ? DS.Color.gold300 : DS.Color.textPrimary)
      Text(model.opensEditor ? "Opens the editor instead." : "Hold ⌥ to edit first.")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
    }
    .padding(DS.Space.s4)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      ZStack {
        shape.fill(DS.Color.bgRaised)
        shape.fill(model.isTargeted ? DS.Color.goldWashActive : DS.Color.goldWash)
      }
    }
    .overlay(
      shape.strokeBorder(
        model.isTargeted ? DS.Color.gold500 : DS.Color.borderGold,
        style: StrokeStyle(lineWidth: DS.Stroke.emphasis, dash: DS.Stroke.dash)
      )
    )
    .clipShape(shape)
    .contentShape(shape)
    .dropDestination(for: URL.self) { urls, _ in
      onDrop(urls)
    } isTargeted: { model.isTargeted = $0 }
    .preferredColorScheme(.dark)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
  }
}
