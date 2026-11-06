import SwiftUI
import VicutCore

struct EditorView: View {
  @Environment(JobQueue.self) private var queue
  @Environment(SettingsStore.self) private var settings
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismiss) private var dismiss
  @State private var model: EditorModel
  @State private var showExportOptions = false

  init(url: URL) {
    _model = State(initialValue: EditorModel(url: url))
  }

  var body: some View {
    VStack(spacing: 12) {
      if let error = model.loadError {
        ContentUnavailableView("Can't open video", systemImage: "exclamationmark.triangle", description: Text(error))
      } else {
        PlayerView(player: model.player)
          .background(Color.black)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        transport
        EditTimelineView(model: model)
        toolbar
        summary
      }
    }
    .padding(16)
    .frame(minWidth: 760, minHeight: 560)
    .navigationTitle(model.url.lastPathComponent)
    .task { await model.load() }
    .onDisappear { model.teardown() }
  }

  private var transport: some View {
    HStack(spacing: 12) {
      Button {
        model.togglePlay()
      } label: {
        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
          .frame(width: 20)
      }
      .keyboardShortcut(.space, modifiers: [])
      .help("Play / Pause (Space)")

      Button { model.step(by: -1) } label: { Image(systemName: "gobackward.5") }
        .keyboardShortcut(.leftArrow, modifiers: [])
        .help("Back 1s (←)")
      Button { model.step(by: 1) } label: { Image(systemName: "goforward.5") }
        .keyboardShortcut(.rightArrow, modifiers: [])
        .help("Forward 1s (→)")

      Text("\(Formatters.duration(model.currentTime)) / \(Formatters.duration(model.duration))")
        .monospacedDigit()
        .foregroundStyle(.secondary)

      Spacer()

      zoomControls

      Toggle("Preview edits", isOn: $model.previewEdits)
        .toggleStyle(.checkbox)
        .help("Skip cut parts and fast-forward sped-up parts while playing")
    }
  }

  private var zoomControls: some View {
    HStack(spacing: 4) {
      Button { model.zoom(by: 1 / EditorModel.zoomStep) } label: { Image(systemName: "minus.magnifyingglass") }
        .keyboardShortcut("-", modifiers: .command)
        .help("Zoom out (⌘−)")
        .disabled(!model.viewport.isZoomed)
      Text(zoomLabel)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(minWidth: 52)
      Button { model.zoom(by: EditorModel.zoomStep) } label: { Image(systemName: "plus.magnifyingglass") }
        .keyboardShortcut("=", modifiers: .command)
        .help("Zoom in (⌘+) · pinch or ⌥-scroll on the timeline")
        .disabled(model.viewport.span <= TimelineViewport.minSpan)
      Button("Fit") { model.zoomToFit() }
        .keyboardShortcut("0", modifiers: .command)
        .help("Show the whole clip (⌘0)")
        .disabled(!model.viewport.isZoomed)
      Button("Zoom to selection") { model.zoomToSelection() }
        .keyboardShortcut("z", modifiers: [])
        .help("Zoom to the selected range (Z)")
        .disabled(!model.hasSelection)
    }
    .controlSize(.small)
  }

  /// Visible span is more useful than a raw factor when editing a 5s part of a 30min clip.
  private var zoomLabel: String {
    model.viewport.isZoomed ? Formatters.duration(model.viewport.span) : "All"
  }

  private var toolbar: some View {
    HStack(spacing: 8) {
      Button("In  I") { model.markIn() }
        .keyboardShortcut("i", modifiers: [])
      Button("Out  O") { model.markOut() }
        .keyboardShortcut("o", modifiers: [])

      Divider().frame(height: 18)

      Button { model.apply(.cut) } label: { Label("Cut  C", systemImage: "scissors") }
        .keyboardShortcut("c", modifiers: [])
      ForEach([2.0, 4.0, 8.0], id: \.self) { factor in
        Button(Formatters.speed(factor)) { model.apply(.speed(factor)) }
          .keyboardShortcut(KeyEquivalent(Character(String(Int(factor)))), modifiers: [])
          .help("Speed up selection \(Formatters.speed(factor)) (\(Int(factor)))")
      }
      Button("Keep  K") { model.apply(.keep) }
        .keyboardShortcut("k", modifiers: [])
        .help("Remove cut/speed from the selection")

      Divider().frame(height: 18)

      Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
        .keyboardShortcut("z", modifiers: .command)
        .disabled(!model.canUndo)
      Button("Reset") { model.resetAll() }
        .disabled(model.marks.isEmpty)

      Spacer()

      Button {
        showExportOptions = true
      } label: {
        Label("Export…", systemImage: "square.and.arrow.up")
      }
      .keyboardShortcut("e", modifiers: .command)
      .buttonStyle(.borderedProminent)
      .disabled(model.outputDuration == nil)
      .popover(isPresented: $showExportOptions, arrowEdge: .top) {
        exportOptions
      }
    }
  }

  private var summary: some View {
    HStack {
      if let notice = model.notice {
        Label(notice, systemImage: "info.circle")
          .foregroundStyle(.orange)
      } else {
        Text("Drag to select (snaps to edges, ⌘ = no snap) · C cut · 2/4/8 speed · Z zoom · ⌘E export")
          .foregroundStyle(.secondary)
      }
      Spacer()
      if let output = model.outputDuration {
        Text("\(Formatters.duration(model.duration)) → \(Formatters.duration(output))")
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
    }
    .font(.callout)
  }

  private var exportOptions: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Export as .mp4")
        .font(.headline)
      exportChoice(
        title: "Full quality",
        detail: "Original resolution and frame rate. No size limit.",
        systemImage: "sparkles.tv",
        fullQuality: true
      )
      exportChoice(
        title: "Compressed",
        detail: settings.summary,
        systemImage: "arrow.down.right.and.arrow.up.left",
        fullQuality: false
      )
    }
    .padding(14)
    .frame(width: 320)
  }

  private func exportChoice(title: String, detail: String, systemImage: String, fullQuality: Bool) -> some View {
    Button {
      export(fullQuality: fullQuality)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: systemImage)
          .font(.title3)
          .frame(width: 26)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.body.weight(.semibold))
          Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.bordered)
  }

  private func export(fullQuality: Bool) {
    showExportOptions = false
    model.teardown()
    queue.enqueueExport(model.url, marks: model.marks, fullQuality: fullQuality)
    openWindow(id: WindowID.main)
    dismiss()
  }
}
