import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
  @Environment(JobQueue.self) private var queue
  @Environment(SettingsStore.self) private var settings
  @Environment(\.openWindow) private var openWindow
  @State private var importAction: DropAction?

  var body: some View {
    VStack(spacing: 0) {
      if queue.jobs.isEmpty {
        dropZones(compact: false)
          .padding(16)
      } else {
        dropZones(compact: true)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
        jobList
      }
      Divider()
      footer
    }
    .frame(minWidth: 520, minHeight: 440)
    .fileImporter(
      isPresented: Binding(get: { importAction != nil }, set: { if !$0 { importAction = nil } }),
      allowedContentTypes: [.movie],
      allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result, let action = importAction {
        _ = handle(urls, action: action)
      }
      importAction = nil
    }
  }

  private func dropZones(compact: Bool) -> some View {
    HStack(spacing: 12) {
      ForEach([DropAction.compress, .edit], id: \.self) { action in
        DropZoneView(
          action: action,
          compact: compact,
          onDrop: { handle($0, action: action) },
          onChoose: { importAction = action }
        )
      }
    }
  }

  private var jobList: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Jobs")
          .font(.headline)
        Spacer()
        Button("Clear finished") { queue.clearFinished() }
          .disabled(!queue.jobs.contains(where: \.isFinished))
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 4)

      List(queue.jobs) { job in
        JobRowView(job: job)
      }
      .listStyle(.inset)
    }
  }

  private var footer: some View {
    HStack {
      Image(systemName: "slider.horizontal.3")
        .foregroundStyle(.secondary)
      Text("Compress: \(settings.summary)")
        .font(.callout)
        .foregroundStyle(.secondary)
      Spacer()
      SettingsLink {
        Text("Settings…")
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private func handle(_ urls: [URL], action: DropAction) -> Bool {
    let videos = urls.filter(JobQueue.isSupported)
    guard !videos.isEmpty else { return false }
    switch action {
    case .compress:
      queue.enqueue(videos)
    case .edit:
      videos.forEach { openWindow(id: WindowID.editor, value: $0) }
    }
    return true
  }
}
