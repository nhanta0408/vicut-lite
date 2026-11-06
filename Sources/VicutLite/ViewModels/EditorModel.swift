import AVFoundation
import Foundation
import Observation
import VicutCore

@MainActor
@Observable
final class EditorModel {
  /// Thumbnails per visible span; one span either side is pre-rendered so panning isn't blank.
  static let thumbnailsPerSpan = 14
  static let minSelection = 0.05
  static let zoomStep = 2.0
  static let thumbnailDebounce = Duration.milliseconds(150)
  /// Length of a span added from the edit menu at the playhead.
  static let newSpanLength = 3.0
  static let toastDuration = Duration.milliseconds(3200)

  struct Thumbnail {
    let range: ClosedRange<Double>
    let image: CGImage
  }

  let url: URL
  let player: AVPlayer
  private(set) var duration: Double = 0
  private(set) var currentTime: Double = 0
  private(set) var isPlaying = false
  private(set) var marks: [Segment] = []
  private(set) var thumbnails: [Thumbnail] = []
  private(set) var viewport = TimelineViewport(duration: 0)
  /// Where the selection edge last snapped, so the timeline can draw a guide.
  var snapGuide: Double?
  private(set) var loadError: String?
  /// A dragged / I–O range; takes priority over `selectedSpanTime` as the edit target.
  var selection: ClosedRange<Double>? {
    didSet {
      if selection != nil { selectedSpanTime = nil }
    }
  }
  /// A time inside the selected span. Spans are re-resolved after every edit, so a time
  /// survives merges and splits where an index or id would not.
  var selectedSpanTime: Double?
  private(set) var toast: EditorToast?
  /// Set when an edit would wipe out whole cut / speed parts; the view asks before applying.
  private(set) var pendingReplace: PendingReplace?
  /// Seam for the Spans list panel (not built yet): the timeline toggle flips it, the layout
  /// reserves a docked slot and a floating overlay for it.
  var spansPanel: SpansPanelMode = .closed
  /// Skip cut parts and fast-forward speed parts while playing, so the preview matches the export.
  var previewEdits = true

  @ObservationIgnored private var undoStack: [[Segment]] = []
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var pendingIn: Double?
  @ObservationIgnored private var asset: AVURLAsset?
  @ObservationIgnored private var thumbnailTask: Task<Void, Never>?
  @ObservationIgnored private var thumbnailWindow: ClosedRange<Double>?
  @ObservationIgnored private var thumbnailSpan: Double?
  @ObservationIgnored private var toastTask: Task<Void, Never>?

  init(url: URL) {
    self.url = url
    player = AVPlayer(url: url)
    player.actionAtItemEnd = .pause
  }

  var resolved: [Segment] {
    duration > 0 ? Timeline.resolve(marks: marks, duration: duration) : []
  }

  var outputDuration: Double? {
    guard duration > 0, let kept = try? Timeline.normalize(marks: marks, duration: duration) else { return nil }
    return Timeline.outputDuration(kept)
  }

  var canUndo: Bool { !undoStack.isEmpty }
  var hasSelection: Bool { selection != nil }

  var selectedSpan: Segment? {
    guard let selectedSpanTime, duration > 0 else { return nil }
    return Timeline.span(at: selectedSpanTime, marks: marks, duration: duration)
  }

  /// What the edit menu and C / 2 / 4 / 8 / K act on: the range selection, else the selected span.
  var editTarget: EditTarget? {
    if let selection {
      return EditTarget(range: selection, action: nil)
    }
    if let span = selectedSpan {
      return EditTarget(range: span.start...span.end, action: span.action)
    }
    return nil
  }

  func load() async {
    let asset = AVURLAsset(url: url)
    do {
      let time = try await asset.load(.duration)
      duration = time.seconds.isFinite ? time.seconds : 0
    } catch {
      loadError = "Can't read this video: \(error.localizedDescription)"
      return
    }
    self.asset = asset
    viewport.setDuration(duration)
    installTimeObserver()
    scheduleThumbnails(debounce: false)
  }

  // MARK: Zoom

  var snapPoints: [Double] {
    Timeline.snapPoints(marks: marks, duration: duration)
  }

  /// Zooms around `anchor`, defaulting to the playhead when it's on screen, else the view centre.
  func zoom(by factor: Double, anchor: Double? = nil) {
    let visiblePlayhead = (viewport.start...viewport.end).contains(currentTime) ? currentTime : nil
    let center = anchor ?? visiblePlayhead ?? (viewport.start + viewport.span / 2)
    updateViewport { $0.zoom(by: factor, anchor: center) }
  }

  func zoomToFit() {
    updateViewport { $0.reset() }
  }

  func zoomToSelection() {
    guard let range = editTarget?.range else {
      flash("Select a range first, then press Z to zoom to it.", isError: true)
      return
    }
    updateViewport { $0.fit(range) }
  }

  func pan(by seconds: Double) {
    updateViewport { $0.pan(by: seconds) }
  }

  func moveViewport(start: Double) {
    updateViewport { $0.moveStart(to: start) }
  }

  private func updateViewport(_ change: (inout TimelineViewport) -> Void) {
    var next = viewport
    change(&next)
    guard next != viewport else { return }
    viewport = next
    scheduleThumbnails(debounce: true)
  }

  func teardown() {
    thumbnailTask?.cancel()
    toastTask?.cancel()
    player.pause()
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
  }

  func togglePlay() {
    if isPlaying {
      player.pause()
      isPlaying = false
    } else {
      if currentTime >= duration - 0.05 {
        seek(to: 0)
      }
      player.play()
      isPlaying = true
    }
  }

  func seek(to seconds: Double) {
    let clamped = min(max(seconds, 0), duration)
    currentTime = clamped
    updateViewport { $0.reveal(clamped) }
    player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
  }

  func step(by seconds: Double) {
    seek(to: currentTime + seconds)
  }

  func markIn() {
    pendingIn = currentTime
    if let selection, selection.upperBound > currentTime {
      self.selection = currentTime...selection.upperBound
    } else {
      selection = nil
    }
  }

  func markOut() {
    let start = pendingIn ?? selection?.lowerBound ?? 0
    guard currentTime - start >= Self.minSelection else { return }
    selection = start...currentTime
  }

  func select(from a: Double, to b: Double) {
    let lower = min(max(min(a, b), 0), duration)
    let upper = min(max(max(a, b), 0), duration)
    selection = upper - lower >= Self.minSelection ? lower...upper : nil
    pendingIn = selection?.lowerBound
  }

  func selectSpan(at time: Double) {
    selection = nil
    pendingIn = nil
    selectedSpanTime = min(max(time, 0), duration)
  }

  /// Applies `action` to the edit target (range selection, else selected span).
  func apply(_ action: SegmentAction) {
    guard let target = editTarget else {
      flash("Select a range first: drag on the timeline, or press I and O.", isError: true)
      return
    }
    guard target.action != action else { return }
    paint(target.range, with: action)
  }

  /// Adds a short span starting at the playhead, as offered by the edit menu.
  func addAtPlayhead(_ action: SegmentAction) {
    let end = min(currentTime + Self.newSpanLength, duration)
    guard end - currentTime >= Self.minSelection else {
      flash("The playhead is at the end of the clip.", isError: true)
      return
    }
    paint(currentTime...end, with: action)
  }

  func confirmPendingReplace() {
    guard let pending = pendingReplace else { return }
    pendingReplace = nil
    commit(pending.range, with: pending.action, trimmed: pending.impact.trimmed)
  }

  func cancelPendingReplace() {
    pendingReplace = nil
  }

  private func paint(_ range: ClosedRange<Double>, with action: SegmentAction) {
    let candidate = marks + [Segment(start: range.lowerBound, end: range.upperBound, action: action)]
    guard (try? Timeline.normalize(marks: candidate, duration: duration)) != nil else {
      flash("That would cut the whole clip.", isError: true)
      return
    }
    let impact = Timeline.overlap(of: range, action: action, marks: marks, duration: duration)
    if !impact.covered.isEmpty {
      pendingReplace = PendingReplace(range: range, action: action, impact: impact)
      return
    }
    commit(range, with: action, trimmed: impact.trimmed)
  }

  private func commit(_ range: ClosedRange<Double>, with action: SegmentAction, trimmed: [Segment]) {
    undoStack.append(marks)
    marks.append(Segment(start: range.lowerBound, end: range.upperBound, action: action))
    selection = nil
    pendingIn = nil
    selectedSpanTime = (range.lowerBound + range.upperBound) / 2
    if trimmed.isEmpty {
      dismissToast()
    } else {
      flash("Trimmed: " + trimmed.map { "\($0.action.title) → \(Self.rangeText($0.start...$0.end, separator: "–"))" }
        .joined(separator: " · "))
    }
  }

  static func rangeText(_ range: ClosedRange<Double>, separator: String = " → ") -> String {
    Formatters.duration(range.lowerBound) + separator + Formatters.duration(range.upperBound)
  }

  // MARK: Toast

  func flash(_ message: String, isError: Bool = false) {
    toast = EditorToast(message: message, isError: isError)
    toastTask?.cancel()
    toastTask = Task { [weak self] in
      try? await Task.sleep(for: Self.toastDuration)
      guard !Task.isCancelled else { return }
      self?.toast = nil
    }
  }

  func dismissToast() {
    toastTask?.cancel()
    toast = nil
  }

  func undo() {
    guard let previous = undoStack.popLast() else { return }
    marks = previous
  }

  func resetAll() {
    guard !marks.isEmpty else { return }
    undoStack.append(marks)
    marks = []
    selection = nil
    pendingIn = nil
  }

  private func installTimeObserver() {
    let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        self?.tick(time.seconds)
      }
    }
  }

  private func tick(_ seconds: Double) {
    guard seconds.isFinite else { return }
    currentTime = seconds
    if isPlaying, player.timeControlStatus == .paused, player.rate == 0 {
      isPlaying = false
    }
    if isPlaying {
      updateViewport { $0.reveal(seconds) }
    }
    guard isPlaying, previewEdits else { return }

    let segment = resolved.first { $0.start <= seconds && seconds < $0.end }
    switch segment?.action {
    case .cut:
      if let end = segment?.end, end < duration - 0.05 {
        seek(to: end)
      } else {
        player.pause()
        isPlaying = false
      }
    case .speed(let factor):
      if player.rate != Float(factor) {
        player.rate = Float(factor)
      }
    case .keep, .none:
      if player.rate != 1 {
        player.rate = 1
      }
    }
  }

  /// Renders thumbnails for the visible span plus one span either side, at keyframe precision.
  private func scheduleThumbnails(debounce: Bool) {
    guard let asset, duration > 0 else { return }
    let window = max(viewport.start - viewport.span, 0)...min(viewport.end + viewport.span, duration)
    // Same zoom level and still inside the pre-rendered window: nothing new to draw.
    if let thumbnailWindow, thumbnailSpan == viewport.span,
       thumbnailWindow.contains(viewport.start), thumbnailWindow.contains(viewport.end) {
      return
    }
    thumbnailTask?.cancel()
    let count = max(Int((window.upperBound - window.lowerBound) / viewport.span * Double(Self.thumbnailsPerSpan)), 1)
    let step = (window.upperBound - window.lowerBound) / Double(count)
    let span = viewport.span
    thumbnailTask = Task { [weak self] in
      if debounce {
        try? await Task.sleep(for: Self.thumbnailDebounce)
      }
      guard !Task.isCancelled else { return }
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 240, height: 160)
      let tolerance = CMTime(seconds: step / 2, preferredTimescale: 600)
      generator.requestedTimeToleranceBefore = tolerance
      generator.requestedTimeToleranceAfter = tolerance
      let times = (0..<count).map {
        CMTime(seconds: window.lowerBound + step * (Double($0) + 0.5), preferredTimescale: 600)
      }
      var images: [Thumbnail] = []
      for await result in generator.images(for: times) {
        guard !Task.isCancelled else { return }
        if let image = try? result.image {
          let start = result.requestedTime.seconds - step / 2
          images.append(Thumbnail(range: start...(start + step), image: image))
        }
      }
      guard !Task.isCancelled, let self else { return }
      self.thumbnails = images
      self.thumbnailWindow = window
      self.thumbnailSpan = span
    }
  }
}

struct EditTarget: Equatable {
  let range: ClosedRange<Double>
  /// nil for a free range selection, which can span several parts.
  let action: SegmentAction?
}

struct EditorToast: Equatable {
  let message: String
  let isError: Bool
}

struct PendingReplace: Equatable {
  let range: ClosedRange<Double>
  let action: SegmentAction
  let impact: OverlapImpact
}

/// Mirrors the canvas `panel` prop: hidden, floating over the stage, or docked beside it.
enum SpansPanelMode: Equatable {
  case closed
  case floating
  case pinned

  var isOpen: Bool { self != .closed }
}

extension SegmentAction {
  var title: String {
    switch self {
    case .keep: "Normal"
    case .cut: "Cut"
    case .speed(let factor): "\(Formatters.speed(factor)) speed"
    }
  }
}
