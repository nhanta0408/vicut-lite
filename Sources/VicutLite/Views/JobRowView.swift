import AppKit
import SwiftUI
import VicutCore

struct JobRowView: View {
  @Environment(JobQueue.self) private var queue
  @Environment(\.openWindow) private var openWindow
  let job: Job
  @State private var showLog = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      statusIcon
        .font(.title2)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 6) {
        Text(job.input.lastPathComponent)
          .font(.headline)
          .lineLimit(1)
          .truncationMode(.middle)
        detail
        actions
      }
    }
    .padding(.vertical, 6)
    .contextMenu {
      Button("Remove") { queue.remove(job) }
    }
  }

  @ViewBuilder private var statusIcon: some View {
    switch job.state {
    case .queued:
      Image(systemName: "clock").foregroundStyle(.secondary)
    case .running:
      ProgressView().controlSize(.small)
    case .done(let result):
      Image(systemName: result.exceedsTarget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .foregroundStyle(result.exceedsTarget ? .orange : .green)
    case .failed:
      Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
    case .cancelled:
      Image(systemName: "stop.circle").foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var detail: some View {
    switch job.state {
    case .queued:
      Text("Waiting… \(Formatters.bytes(job.originalBytes))").foregroundStyle(.secondary)
    case .running(let fraction):
      ProgressView(value: fraction)
      Text("\(job.kind.verb) \(Int(fraction * 100))%").font(.caption).foregroundStyle(.secondary)
    case .done(let result):
      Text(sizeChange(result)).monospacedDigit()
      Text("\(result.plan.width)×\(result.plan.height) · \(result.plan.fps) fps · \(result.output.lastPathComponent)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
      if result.exceedsTarget {
        Text("Still above the size target — try a lower resolution or cut more.")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    case .failed(let message, _):
      Text(message).foregroundStyle(.red).font(.callout)
    case .cancelled:
      Text("Cancelled").foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var actions: some View {
    HStack(spacing: 8) {
      switch job.state {
      case .queued, .running:
        Button("Cancel") { queue.cancel(job) }
      case .done(let result):
        Button("Copy") { copy(result.output) }
          .help("Copy the file, then paste it into a GitHub comment")
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([result.output]) }
        Button("Edit…") { openWindow(id: WindowID.editor, value: job.input) }
        Image(systemName: "hand.draw")
          .foregroundStyle(.secondary)
          .help("Drag this row into a browser to upload")
      case .failed(_, let log):
        Button("Edit…") { openWindow(id: WindowID.editor, value: job.input) }
        if !log.isEmpty {
          Button("Show log") { showLog = true }
            .popover(isPresented: $showLog) {
              ScrollView {
                Text(log.joined(separator: "\n"))
                  .font(.system(.caption, design: .monospaced))
                  .textSelection(.enabled)
                  .padding()
              }
              .frame(width: 520, height: 260)
            }
        }
      case .cancelled:
        Button("Remove") { queue.remove(job) }
      }
    }
    .controlSize(.small)
    .onDrag {
      if case .done(let result) = job.state, let provider = NSItemProvider(contentsOf: result.output) {
        return provider
      }
      return NSItemProvider()
    }
  }

  private func sizeChange(_ result: ExportResult) -> String {
    let before = Formatters.bytes(job.originalBytes)
    let after = Formatters.bytes(result.bytes)
    guard job.originalBytes > 0 else { return after }
    let saved = 100 - Int((Double(result.bytes) / Double(job.originalBytes) * 100).rounded())
    return "\(before) → \(after) (−\(saved)%)"
  }

  private func copy(_ url: URL) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([url as NSURL])
  }
}
