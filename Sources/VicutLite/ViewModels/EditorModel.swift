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
  var selection: ClosedRange<Double>?
  var notice: String?
  /// Skip cut parts and fast-forward speed parts while playing, so the preview matches the export.
  var previewEdits = true

  @ObservationIgnored private var undoStack: [[Segment]] = []
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var pendingIn: Double?
  @ObservationIgnored private var asset: AVURLAsset?
  @ObservationIgnored private var thumbnailTask: Task<Void, Never>?
  @ObservationIgnored private var thumbnailWindow: ClosedRange<Double>?
  @ObservationIgnored private var thumbnailSpan: Double?

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
    guard let selection else {
      notice = "Select a range first, then press Z to zoom to it."
      return
    }
    updateViewport { $0.fit(selection) }
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

  func apply(_ action: SegmentAction) {
    guard let selection else {
      notice = "Select a range first: drag on the timeline, or press I and O."
      return
    }
    let candidate = marks + [Segment(start: selection.lowerBound, end: selection.upperBound, action: action)]
    guard (try? Timeline.normalize(marks: candidate, duration: duration)) != nil else {
      notice = "That would cut the whole clip."
      return
    }
    undoStack.append(marks)
    marks = candidate
    self.selection = nil
    pendingIn = nil
    notice = nil
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
