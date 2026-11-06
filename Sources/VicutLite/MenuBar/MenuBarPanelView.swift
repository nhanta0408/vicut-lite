import AppKit
import SwiftUI
import VicutCore

/// Content of the status item popover: a compact drop target, the latest jobs, and app commands.
struct MenuBarPanelView: View {
  @Environment(JobQueue.self) private var queue
  let onDrop: ([URL], DropAction) -> Bool
  let onOpenApp: () -> Void
  let onOpenSettings: () -> Void
  @State private var isDropTargeted = false
  @State private var isOptionHeld = false

  /// Same polling as MainView: during a drag the popover's app isn't key, so it gets no flagsChanged.
  private static let modifierPollInterval = Duration.milliseconds(100)

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Space.s3) {
      header
      DropZoneView(isTargeted: isDropTargeted, opensEditor: isOptionHeld)
        .dropDestination(for: URL.self) { urls, _ in
          onDrop(urls, NSEvent.modifierFlags.contains(.option) ? .edit : .compress)
        } isTargeted: { isDropTargeted = $0 }
        .task(id: isDropTargeted) { await trackOptionKey() }
      jobs
      SettingsDivider()
      commands
    }
    .padding(DS.Space.s3)
    .frame(width: DS.Size.menuBarPanelWidth)
    .background(DS.Color.bgRaised)
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack(spacing: DS.Space.s2) {
      BrandMark()
        .frame(width: DS.Size.brandMark, height: DS.Size.brandMark)
      (Text("ViCut ").foregroundStyle(DS.Color.textPrimary) + Text("Lite").foregroundStyle(DS.Color.gold500))
        .dsText(DS.Typography.heading)
      Spacer(minLength: DS.Space.s2)
      Text("\(queue.jobs.filter(\.isActive).count) in progress")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .monospacedDigit()
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var jobs: some View {
    let recent = Array(queue.jobs.prefix(DS.Size.menuBarJobLimit))
    if recent.isEmpty {
      Text("No videos yet. Drop one above or on the menu bar icon.")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      VStack(spacing: DS.Space.s1) {
        ForEach(recent) { job in
          MenuBarJobRow(job: job)
        }
        if queue.jobs.count > recent.count {
          Text("+\(queue.jobs.count - recent.count) more in the window")
            .dsText(DS.Typography.caption)
            .foregroundStyle(DS.Color.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private var commands: some View {
    VStack(spacing: 0) {
      command("Open ViCut Lite", systemImage: "macwindow", action: onOpenApp)
      command("Settings…", systemImage: "gearshape", action: onOpenSettings)
      command("Quit ViCut Lite", systemImage: "power") { NSApp.terminate(nil) }
    }
  }

  private func command(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: DS.Space.s2) {
        DSIcon(systemImage, size: DS.Size.glyphSmall)
          .foregroundStyle(DS.Color.textSecondary)
        Text(title)
          .dsText(DS.Typography.body)
        Spacer(minLength: 0)
      }
    }
    .buttonStyle(DSMenuItemButtonStyle())
  }

  private func trackOptionKey() async {
    while isDropTargeted, !Task.isCancelled {
      isOptionHeld = NSEvent.modifierFlags.contains(.option)
      try? await Task.sleep(for: Self.modifierPollInterval)
    }
    isOptionHeld = false
  }
}

/// One-line job summary: name, then progress / size / failure, with file actions once done.
private struct MenuBarJobRow: View {
  let job: Job

  var body: some View {
    HStack(spacing: DS.Space.s2) {
      VStack(alignment: .leading, spacing: DS.Space.s1) {
        Text(job.input.lastPathComponent)
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.textPrimary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(job.input.path)
        status
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let result = job.result {
        DSButtonGroup {
          Button { FileActions.copy(result.output) } label: {
            DSIcon("doc.on.doc", size: DS.Size.glyphSmall)
          }
          .buttonStyle(DSIconButtonStyle(size: .small))
          .help("Copy file")
          .accessibilityLabel("Copy file")
          Button { FileActions.reveal(result.output) } label: {
            DSIcon("folder", size: DS.Size.glyphSmall)
          }
          .buttonStyle(DSIconButtonStyle(size: .small))
          .help("Show in Finder")
          .accessibilityLabel("Show in Finder")
        }
      }
    }
    .padding(DS.Space.s2)
    .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(DS.Color.bgCard))
    .opacity(isQueued ? DS.Opacity.queued : 1)
  }

  @ViewBuilder private var status: some View {
    switch job.state {
    case .queued:
      caption("Waiting in queue", color: DS.Color.textMuted)
    case .running(let fraction):
      DSProgressBar(value: fraction)
    case .done(let result):
      HStack(spacing: DS.Space.s2) {
        caption(Formatters.bytes(result.bytes), color: DS.Color.textSecondary)
        if let saved = QueueFormat.savedPercent(original: job.originalBytes, output: result.bytes) {
          DSBadge(text: saved)
        }
      }
    case .failed(let message, _):
      caption(message, color: DS.Color.dangerText)
        .help(message)
    case .cancelled:
      caption("Cancelled", color: DS.Color.textFaint)
    }
  }

  private func caption(_ text: String, color: Color) -> some View {
    Text(text)
      .dsText(DS.Typography.caption)
      .foregroundStyle(color)
      .lineLimit(1)
  }

  private var isQueued: Bool {
    if case .queued = job.state { true } else { false }
  }
}
