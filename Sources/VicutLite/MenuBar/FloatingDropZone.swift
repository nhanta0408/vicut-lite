import AppKit
import Observation
import SwiftUI
import VicutCore

/// Clop-style drop zone: when a video drag starts in any app, a small panel slides in at the
/// bottom-right of that screen; dropping on it compresses (⌥: opens the editor). After a drop it
/// turns into a progress card for those videos and hides itself a few seconds after they finish.
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
  private var autoHideTask: Task<Void, Never>?
  /// Bumped on every show / hide so a finishing hide animation can't order out a newer show.
  private var generation = 0
  private(set) var isAvailable = true

  /// Fast enough for the ⌥ hint to feel live, cheap enough to run for a whole drag.
  private static let pollInterval = Duration.milliseconds(80)
  /// The drop message can arrive just after the button-up we poll for; give it time to land.
  private static let releaseGrace = Duration.milliseconds(250)
  /// How long the finished card stays up (paused while hovered) before sliding away.
  private static let resultLinger: TimeInterval = 6
  private static let autoHideCheck = Duration.milliseconds(500)

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
    // A progress card gives way to the drop zone when the next video drag starts.
    guard panel?.isVisible != true || model.mode == .progress else { return }
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
    autoHideTask?.cancel()
    model.mode = .drop
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

  /// Shows (or updates) the progress card for `jobs`, anchored to the same corner as the drop zone.
  func showProgress(_ jobs: [Job]) {
    pollTask?.cancel()
    pollTask = nil
    autoHideTask?.cancel()
    let panel = panel ?? makePanel()
    self.panel = panel
    let wasShowingProgress = panel.isVisible && model.mode == .progress
    model.jobs = (wasShowingProgress ? model.jobs.filter { !$0.isFinished } : []) + jobs
    model.mode = .progress
    model.isHovered = false
    generation += 1

    let size = progressCardSize()
    let screenFrame = panel.isVisible ? panel.screen?.visibleFrame : nil
    let screens = NSScreen.screens
    guard let visible = screenFrame ?? DropZonePlacement.screenIndex(
      containing: NSEvent.mouseLocation, screens: screens.map(\.frame)
    ).map({ screens[$0].visibleFrame }) else { return }
    let target = DropZonePlacement.frame(size: size, in: visible, margin: DS.Space.floatingDropZoneMargin)
    if !panel.isVisible {
      panel.setFrame(target, display: false)
      panel.alphaValue = 0
      panel.orderFrontRegardless()
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = DS.Motion.floatingDropZoneDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
      panel.animator().setFrame(target, display: true)
    }
    scheduleAutoHide()
  }

  /// Polled so it also catches jobs finishing while nothing else changes on the card.
  private func scheduleAutoHide() {
    autoHideTask?.cancel()
    autoHideTask = Task { [weak self] in
      var finishedAt: Date?
      while !Task.isCancelled {
        guard let self else { return }
        if self.model.jobs.allSatisfy(\.isFinished), !self.model.isHovered {
          let since = finishedAt ?? Date()
          finishedAt = since
          if Date().timeIntervalSince(since) >= Self.resultLinger {
            self.hide(animated: true)
            return
          }
        } else {
          finishedAt = nil
        }
        try? await Task.sleep(for: Self.autoHideCheck)
      }
    }
  }

  /// Measured on a throwaway host: the panel's own host only re-renders on the next run loop pass,
  /// so it would still report the drop zone's size.
  private func progressCardSize() -> CGSize {
    let probe = NSHostingView(rootView: FloatingProgressCard(model: model, onOpenApp: {}, onClose: {}))
    return probe.fittingSize
  }

  private func hide(animated: Bool) {
    pollTask?.cancel()
    pollTask = nil
    autoHideTask?.cancel()
    autoHideTask = nil
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
    // A compress drop has already turned the panel into its progress card.
    if model.mode != .progress { hide(animated: true) }
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
    let root = FloatingDropZoneView(
      model: model,
      onDrop: { [weak self] urls in self?.drop(urls) ?? false },
      onOpenApp: { [weak self] in
        self?.hide(animated: true)
        self?.actions.showMainWindow()
      },
      onClose: { [weak self] in self?.hide(animated: true) }
    )
    panel.contentView = NSHostingView(rootView: root)
    return panel
  }
}

/// Non-activating and never main, so the app the user is dragging from keeps focus. It may become
/// key only if a control needs it (`becomesKeyOnlyIfNeeded`), which lets the card's buttons click.
private final class FloatingDropZonePanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
@Observable
private final class FloatingDropZoneModel {
  enum Mode {
    case drop
    case progress
  }

  var mode: Mode = .drop
  var isTargeted = false
  var opensEditor = false
  var jobs: [Job] = []
  var isHovered = false
}

private struct FloatingDropZoneView: View {
  let model: FloatingDropZoneModel
  let onDrop: ([URL]) -> Bool
  let onOpenApp: () -> Void
  let onClose: () -> Void

  var body: some View {
    switch model.mode {
    case .drop:
      FloatingDropTarget(model: model, onDrop: onDrop)
        .frame(width: DS.Size.floatingDropZone.width, height: DS.Size.floatingDropZone.height)
    case .progress:
      FloatingProgressCard(model: model, onOpenApp: onOpenApp, onClose: onClose)
    }
  }
}

/// The drop face: same gold dashed language as `DropZoneView`, on an opaque card because it
/// floats over other apps.
private struct FloatingDropTarget: View {
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

/// What happens to the videos just dropped: progress while encoding, then size, saving and the
/// two things people do next (copy, reveal). Clicking "Open ViCut Lite" shows the full queue.
private struct FloatingProgressCard: View {
  let model: FloatingDropZoneModel
  let onOpenApp: () -> Void
  let onClose: () -> Void

  private var shown: [Job] { Array(model.jobs.prefix(DS.Size.floatingProgressRows)) }
  private var hiddenCount: Int { max(0, model.jobs.count - DS.Size.floatingProgressRows) }

  private var title: String {
    let active = model.jobs.filter(\.isActive).count
    if active > 0 { return "Compressing \(QueueFormat.videoCount(active))…" }
    let saved = model.jobs.compactMap { job in job.result.map { max(0, job.originalBytes - $0.bytes) } }
    if saved.isEmpty { return "Couldn't compress" }
    return "Done · saved \(Formatters.bytes(saved.reduce(0, +)))"
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
    VStack(alignment: .leading, spacing: DS.Space.s3) {
      header
      ForEach(shown) { job in
        FloatingJobRow(job: job)
      }
      if hiddenCount > 0 {
        Text("+\(hiddenCount) more in ViCut Lite")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
      }
      Button("Open ViCut Lite", action: onOpenApp)
        .buttonStyle(DSGhostButtonStyle(size: .small, bordered: false))
    }
    .padding(DS.Space.s4)
    .frame(width: DS.Size.floatingProgressWidth, alignment: .leading)
    .background(shape.fill(DS.Color.bgRaised))
    .overlay(shape.strokeBorder(DS.Color.borderGold, lineWidth: DS.Stroke.hairline))
    .clipShape(shape)
    .onHover { model.isHovered = $0 }
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack(spacing: DS.Space.s2) {
      DSIcon(model.jobs.contains(where: \.isActive) ? "arrow.down.circle" : "checkmark.circle", size: DS.Size.glyph)
        .foregroundStyle(DS.Color.gold500)
      Text(title)
        .dsText(DS.Typography.heading)
        .foregroundStyle(DS.Color.textPrimary)
        .lineLimit(1)
      Spacer(minLength: 0)
      Button(action: onClose) {
        DSIcon("xmark", size: DS.Size.glyphSmall)
      }
      .buttonStyle(DSIconButtonStyle(size: .small))
      .help("Hide")
      .accessibilityLabel("Hide")
    }
  }
}

private struct FloatingJobRow: View {
  let job: Job

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.s1) {
      Text(job.input.lastPathComponent)
        .dsText(DS.Typography.label)
        .foregroundStyle(DS.Color.textPrimary)
        .lineLimit(1)
        .truncationMode(.middle)
      status
        .frame(height: DS.Size.floatingProgressLine)
    }
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var status: some View {
    switch job.state {
    case .queued:
      caption("Waiting…")
    case .running(let fraction):
      HStack(spacing: DS.Space.s2) {
        DSProgressBar(value: fraction)
        Text("\(Int((fraction * 100).rounded()))%")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.gold300)
          .monospacedDigit()
      }
    case .done(let result):
      HStack(spacing: DS.Space.s2) {
        Text(Formatters.bytes(result.bytes))
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.textPrimary)
        if let saved = QueueFormat.savedPercent(original: job.originalBytes, output: result.bytes) {
          DSBadge(text: saved)
        }
        Spacer(minLength: 0)
        Button { FileActions.copy(result.output) } label: { DSIcon("doc.on.doc", size: DS.Size.glyphSmall) }
          .buttonStyle(DSIconButtonStyle(size: .small))
          .help("Copy file (paste into GitHub, Slack, Mail…)")
          .accessibilityLabel("Copy file")
        Button { FileActions.reveal(result.output) } label: { DSIcon("folder", size: DS.Size.glyphSmall) }
          .buttonStyle(DSIconButtonStyle(size: .small))
          .help("Show in Finder")
          .accessibilityLabel("Show in Finder")
      }
    case .failed(let message, _):
      caption(message, color: DS.Color.dangerText)
    case .cancelled:
      caption("Cancelled")
    }
  }

  private func caption(_ text: String, color: Color = DS.Color.textMuted) -> some View {
    Text(text)
      .dsText(DS.Typography.caption)
      .foregroundStyle(color)
      .lineLimit(1)
  }
}
