import AppKit
import SwiftUI
import VicutCore

/// One card in the Queue: thumbnail, names, state line, and state-specific actions.
struct JobRowView: View {
  @Environment(JobQueue.self) private var queue
  @Environment(\.openWindow) private var openWindow
  let job: Job
  let isSelecting: Bool
  let isSelected: Bool
  let onToggleSelection: () -> Void
  /// Asks the parent to confirm moving this job's original to the Trash.
  let onTrashOriginal: () -> Void
  @State private var showLog = false
  @State private var hovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
    HStack(spacing: DS.Space.s3) {
      if isSelecting {
        DSCheckbox(
          isOn: isSelected,
          isEnabled: job.canTrashOriginal,
          label: "Select \(job.input.lastPathComponent)",
          toggle: onToggleSelection
        )
      }
      JobThumbnailView(url: job.input, progress: runningFraction)
      info
      Spacer(minLength: 0)
      actions
    }
    .padding(DS.Space.s3)
    .background(shape.fill(hovered ? DS.Color.bgCardHover : DS.Color.bgCard))
    .overlay(shape.strokeBorder(borderColor, lineWidth: DS.Stroke.hairline))
    .contentShape(shape)
    .opacity(isQueued ? DS.Opacity.queued : 1)
    .onHover { hovered = $0 }
    .onTapGesture {
      if isSelecting, job.canTrashOriginal { onToggleSelection() }
    }
    .onDrag { dragProvider() }
    .help(job.result == nil ? "" : "Drag to Slack, Mail, Finder…")
    .contextMenu { contextMenu }
    .animation(DS.Motion.quick, value: hovered)
  }

  // MARK: Info column

  private var info: some View {
    VStack(alignment: .leading, spacing: DS.Space.s1) {
      Text(job.input.lastPathComponent)
        .dsText(DS.Typography.bodyStrong)
        .foregroundStyle(DS.Color.textPrimary)
        .lineLimit(1)
        .truncationMode(.middle)
        .help(job.input.path)
      HStack(spacing: DS.Space.s1) {
        DSIcon("arrow.turn.down.right", size: DS.Size.glyphSmall)
          .foregroundStyle(DS.Color.gold500)
        Text(QueueFormat.expectedOutputName(for: job))
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      statusLine
        .padding(.top, DS.Space.s0_5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var statusLine: some View {
    switch job.state {
    case .queued:
      HStack(spacing: DS.Space.s2) {
        DSIcon("clock", size: DS.Size.glyphSmall)
        Text("Waiting in queue").dsText(DS.Typography.caption)
      }
      .foregroundStyle(DS.Color.textMuted)
    case .running(let fraction):
      VStack(alignment: .leading, spacing: DS.Space.s1) {
        DSProgressBar(value: fraction)
        HStack(spacing: DS.Space.s2) {
          Text(job.kind.verb)
            .dsText(DS.Typography.label)
            .foregroundStyle(DS.Color.gold300)
          if let target = job.settings.targetBytes, target < job.originalBytes {
            Text("~\(Formatters.bytes(target))").dsText(DS.Typography.caption)
          }
          Spacer(minLength: 0)
          if let eta = QueueFormat.remaining(startedAt: job.startedAt, fraction: fraction) {
            Text(eta).dsText(DS.Typography.caption)
          }
        }
        .foregroundStyle(DS.Color.textMuted)
      }
    case .done(let result):
      doneLine(result)
    case .failed(let message, _):
      HStack(spacing: DS.Space.s2) {
        DSIcon("exclamationmark.triangle.fill", size: DS.Size.glyphSmall)
        Text(message).dsText(DS.Typography.caption).lineLimit(2)
      }
      .foregroundStyle(DS.Color.dangerText)
      .help(message)
    case .cancelled:
      HStack(spacing: DS.Space.s2) {
        DSIcon("stop.circle", size: DS.Size.glyphSmall)
        Text("Cancelled").dsText(DS.Typography.caption)
      }
      .foregroundStyle(DS.Color.textFaint)
    }
  }

  private func doneLine(_ result: ExportResult) -> some View {
    HStack(spacing: DS.Space.s2) {
      Text(Formatters.bytes(result.bytes))
        .dsText(DS.Typography.bodyBold)
        .foregroundStyle(DS.Color.textPrimary)
      if let saved = QueueFormat.savedPercent(original: job.originalBytes, output: result.bytes) {
        DSBadge(text: saved)
      }
      if result.exceedsTarget {
        Text("· above size target")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.dangerText)
          .help("Still above the size target — try a lower resolution or cut more.")
      }
      if job.originalTrashed {
        Text("· original in Trash")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textFaint)
      }
    }
    .lineLimit(1)
    .help("\(Formatters.bytes(job.originalBytes)) → \(Formatters.bytes(result.bytes)) · "
      + "\(result.plan.width)×\(result.plan.height) · \(result.plan.fps) fps")
  }

  // MARK: Actions

  @ViewBuilder private var actions: some View {
    switch job.state {
    case .queued:
      Button { editFirst() } label: {
        Label("Edit first", systemImage: "scissors")
      }
      .buttonStyle(DSInsetButtonStyle())
      .help("Open in the editor before compressing")
    case .running:
      Button { queue.cancel(job) } label: {
        DSIcon("xmark")
      }
      .buttonStyle(DSIconButtonStyle(size: .large, bordered: true, inset: true))
      .help("Cancel")
      .accessibilityLabel("Cancel \(job.kind.verb.lowercased())")
    case .done(let result):
      DSButtonGroup {
        editButton
        Button { NSWorkspace.shared.activateFileViewerSelecting([result.output]) } label: {
          DSIcon("folder", size: DS.Size.glyphLarge)
        }
        .buttonStyle(DSIconButtonStyle())
        .help("Show in Finder")
        .accessibilityLabel("Show in Finder")
        if job.canTrashOriginal {
          Button(action: onTrashOriginal) {
            DSIcon("trash")
          }
          .buttonStyle(DSIconButtonStyle(tone: .danger))
          .help("Delete original (keep compressed)")
          .accessibilityLabel("Move original file to Trash")
        }
      }
    case .failed(_, let log):
      DSButtonGroup {
        editButton
        if !log.isEmpty {
          Button { showLog = true } label: {
            DSIcon("doc.text.magnifyingglass")
          }
          .buttonStyle(DSIconButtonStyle())
          .help("Show ffmpeg log")
          .popover(isPresented: $showLog) { logView(log) }
        }
        removeButton
      }
    case .cancelled:
      DSButtonGroup {
        editButton
        removeButton
      }
    }
  }

  private var editButton: some View {
    Button { openWindow(id: WindowID.editor, value: editableURL) } label: {
      Label("Edit", systemImage: "scissors")
    }
    .buttonStyle(DSPrimaryButtonStyle())
    .help("Edit video")
  }

  private var removeButton: some View {
    Button { queue.remove(job) } label: {
      DSIcon("xmark")
    }
    .buttonStyle(DSIconButtonStyle())
    .help("Remove from queue")
    .accessibilityLabel("Remove from queue")
  }

  private func logView(_ log: [String]) -> some View {
    ScrollView {
      Text(log.joined(separator: "\n"))
        .dsText(DS.Typography.microRegular)
        .foregroundStyle(DS.Color.textSecondary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.s4)
    }
    .frame(width: DS.Size.logPopover.width, height: DS.Size.logPopover.height)
    .background(DS.Color.bgRaised)
  }

  @ViewBuilder private var contextMenu: some View {
    if let result = job.result {
      Button("Copy File") { copy(result.output) }
      Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([result.output]) }
      Divider()
    }
    Button("Remove") { queue.remove(job) }
    Button("Clear Finished") { queue.clearFinished() }
      .disabled(!queue.jobs.contains(where: \.isFinished))
  }

  // MARK: Helpers

  private var runningFraction: Double? {
    if case .running(let fraction) = job.state { fraction } else { nil }
  }

  private var isQueued: Bool {
    if case .queued = job.state { true } else { false }
  }

  private var borderColor: SwiftUI.Color {
    if isSelected { return DS.Color.gold500 }
    return hovered ? DS.Color.borderCardHover : DS.Color.borderSubtle
  }

  /// After the original is trashed, the output is the only copy left to edit.
  private var editableURL: URL {
    if job.originalTrashed, let result = job.result { return result.output }
    return job.input
  }

  private func editFirst() {
    queue.remove(job)
    openWindow(id: WindowID.editor, value: job.input)
  }

  private func dragProvider() -> NSItemProvider {
    if let result = job.result, let provider = NSItemProvider(contentsOf: result.output) {
      return provider
    }
    return NSItemProvider()
  }

  /// Pasting a file URL into a GitHub comment uploads it.
  private func copy(_ url: URL) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
  }
}
