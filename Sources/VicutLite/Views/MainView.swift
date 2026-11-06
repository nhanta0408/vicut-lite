import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Queue window, Home state: title bar, drop bar, job list, footer / selection bar.
struct MainView: View {
  @Environment(JobQueue.self) private var queue
  @Environment(\.openWindow) private var openWindow
  @State private var importAction: DropAction?
  @State private var isDropTargeted = false
  @State private var isSelecting = false
  @State private var selection: Set<Job.ID> = []
  /// Jobs waiting for the "Move to Trash?" confirmation; nil when the dialog is closed.
  @State private var trashCandidates: [Job]?
  /// Hook for the upcoming side tab bar; toggled from the title bar.
  @State private var isSidebarVisible = false
  /// File names that could not be trashed (e.g. moved or on a read-only volume).
  @State private var trashFailures: [String] = []

  var body: some View {
    VStack(spacing: 0) {
      QueueTitleBar(
        doneCount: queue.jobs.filter { $0.result != nil }.count,
        activeCount: queue.jobs.filter(\.isActive).count,
        isSidebarVisible: $isSidebarVisible,
        onHome: { exitSelection() }
      )
      home
      if isSelecting {
        SelectionBarView(
          selectedCount: selectedJobs.count,
          freedBytes: selectedJobs.reduce(0) { $0 + $1.originalBytes },
          onCancel: exitSelection,
          onDelete: { trashCandidates = selectedJobs }
        )
      } else {
        QueueFooterView(savedBytes: queue.sessionSavedBytes, onAddVideos: { importAction = .compress })
      }
    }
    .frame(minWidth: DS.Size.queueWindowMin.width, minHeight: DS.Size.queueWindowMin.height)
    .background(DS.Color.bgApp)
    .ignoresSafeArea(.container, edges: .top)
    .preferredColorScheme(.dark)
    .dsDialog(isPresented: trashCandidates != nil, onDismiss: { trashCandidates = nil }) {
      TrashOriginalsDialog(
        jobs: trashCandidates ?? [],
        onCancel: { trashCandidates = nil },
        onConfirm: confirmTrash
      )
    }
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
    .alert(
      "Couldn't move \(trashFailures.count == 1 ? "the original" : "\(trashFailures.count) originals") to Trash",
      isPresented: Binding(get: { !trashFailures.isEmpty }, set: { if !$0 { trashFailures = [] } })
    ) {
      Button("OK", role: .cancel) { trashFailures = [] }
    } message: {
      Text(trashFailures.joined(separator: "\n"))
    }
    .onChange(of: queue.jobs.map(\.id)) { _, ids in
      selection.formIntersection(ids)
    }
  }

  // MARK: Home content

  private var home: some View {
    VStack(spacing: 0) {
      DropZoneView(isTargeted: isDropTargeted)
        .padding(.horizontal, DS.Space.s4)
        .padding(.top, DS.Space.s3)
        .padding(.bottom, DS.Space.s1)
      if queue.jobs.isEmpty {
        emptyState
      } else {
        jobList
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .dropDestination(for: URL.self) { urls, _ in
      // ⌥ at drop time routes to the editor instead of the compress queue.
      handle(urls, action: NSEvent.modifierFlags.contains(.option) ? .edit : .compress)
    } isTargeted: { isDropTargeted = $0 }
  }

  private var jobList: some View {
    ScrollView {
      LazyVStack(spacing: DS.Space.s2) {
        listHeader
        ForEach(queue.jobs) { job in
          JobRowView(
            job: job,
            isSelecting: isSelecting,
            isSelected: selection.contains(job.id),
            onToggleSelection: { toggle(job) },
            onTrashOriginal: { trashCandidates = [job] }
          )
        }
      }
      .padding(.horizontal, DS.Space.s4)
      .padding(.top, DS.Space.s2)
      .padding(.bottom, DS.Space.s3)
    }
    .scrollIndicators(.automatic)
  }

  private var listHeader: some View {
    let finished = queue.jobs.filter { $0.result != nil }.count
    return HStack(spacing: DS.Space.s2) {
      Text("\(QueueFormat.videoCount(queue.jobs.count)) · \(finished) finished")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
      Spacer(minLength: 0)
      if isSelecting {
        Button("Select all finished") {
          selection = Set(queue.jobs.filter(\.canTrashOriginal).map(\.id))
        }
        .buttonStyle(DSGhostButtonStyle(size: .small, bordered: false))
      }
      Button {
        isSelecting ? exitSelection() : (isSelecting = true)
      } label: {
        Label(isSelecting ? "Done" : "Select", systemImage: "checkmark.square")
      }
      .buttonStyle(DSGhostButtonStyle(size: .small, isActive: isSelecting))
      .help("Select finished videos to delete their originals")
    }
    .padding(.horizontal, DS.Space.s0_5)
    .frame(height: DS.Size.hitMin)
  }

  private var emptyState: some View {
    VStack(spacing: DS.Space.s3) {
      Spacer()
      DSIcon("film.stack", size: DS.Size.emptyStateGlyph)
        .foregroundStyle(DS.Color.borderGold)
      Text("No videos yet")
        .dsText(DS.Typography.heading)
        .foregroundStyle(DS.Color.textPrimary)
      Text("Drop screen recordings anywhere in this window, or click Add videos.\nHold ⌥ while dropping to open the editor first.")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .multilineTextAlignment(.center)
      Button {
        importAction = .edit
      } label: {
        Label("Open in editor…", systemImage: "scissors")
      }
      .buttonStyle(DSGhostButtonStyle())
      .padding(.top, DS.Space.s1)
      Spacer()
    }
    .padding(DS.Space.s5)
    .frame(maxWidth: .infinity)
  }

  // MARK: Selection

  private var selectedJobs: [Job] {
    queue.jobs.filter { selection.contains($0.id) && $0.canTrashOriginal }
  }

  private func toggle(_ job: Job) {
    if selection.contains(job.id) {
      selection.remove(job.id)
    } else {
      selection.insert(job.id)
    }
  }

  private func exitSelection() {
    isSelecting = false
    selection = []
  }

  private func confirmTrash() {
    trashFailures = queue.trashOriginals(trashCandidates ?? []).map(\.input.lastPathComponent)
    trashCandidates = nil
    exitSelection()
  }

  // MARK: Intake

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
