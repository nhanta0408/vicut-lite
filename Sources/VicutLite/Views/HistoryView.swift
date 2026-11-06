import AppKit
import SwiftUI
import VicutCore

/// Full-window History page: past exports grouped by day. Navigation (breadcrumb, tab bar) belongs to the host.
struct HistoryView: View {
  @Environment(HistoryStore.self) private var history
  /// Called on Escape so the host can return to the previous page; nil disables it.
  var onBack: (() -> Void)?

  @State private var confirmClear = false

  init(onBack: (() -> Void)? = nil) {
    self.onBack = onBack
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      if history.entries.isEmpty {
        HistoryEmptyState()
      } else {
        list
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.Color.bgApp)
    .onAppear { history.refreshAvailability() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      history.refreshAvailability()
    }
    .onExitCommand(perform: onBack)
    .confirmationDialog("Clear all history?", isPresented: $confirmClear) {
      Button("Clear History", role: .destructive) { history.clear() }
    } message: {
      Text("Exported files stay where they are. Only this list is cleared.")
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: DS.Space.s2_5) {
      Text("History")
        .dsText(DS.Typography.page)
        .foregroundStyle(DS.Color.textPrimary)
        .help("Snapshot of past exports. Moved or deleted files show as Not found.")
        .accessibilityAddTraits(.isHeader)
      Text(summary)
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
      Spacer(minLength: DS.Space.s2)
      if !history.entries.isEmpty {
        Button("Clear") { confirmClear = true }
          .buttonStyle(GhostTextButtonStyle())
          .help("Remove every entry from History")
      }
    }
    .padding(.horizontal, DS.Space.s5)
    .padding(.top, DS.Space.s5)
    .padding(.bottom, DS.Space.s1)
  }

  private var summary: String {
    let count = history.entries.count
    let exports = count == 1 ? "1 export" : "\(count) exports"
    let missing = history.missingCount
    return missing == 0 ? exports : "\(exports) · \(missing) not found"
  }

  private var list: some View {
    ScrollView {
      LazyVStack(spacing: DS.Space.s2) {
        ForEach(history.sections()) { section in
          HistoryGroupHeader(title: section.group.title, count: section.entries.count)
          ForEach(section.entries) { entry in
            HistoryItemRow(
              entry: entry,
              when: HistoryDateLabel.text(for: entry.date, group: section.group),
              isFound: history.isFound(entry),
              onRemove: { history.remove(entry) }
            )
          }
        }
      }
      .padding(.horizontal, DS.Space.s5)
      .padding(.top, DS.Space.s3)
      .padding(.bottom, DS.Space.s5)
    }
    .scrollContentBackground(.hidden)
  }
}

/// One export: name, folder path, size + saving, time, and Finder/Not-found trailing element.
struct HistoryItemRow: View {
  let entry: HistoryEntry
  let when: String
  let isFound: Bool
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: DS.Space.s2_5) {
      VStack(alignment: .leading, spacing: DS.Space.s1) {
        Text(entry.outputName)
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.textPrimary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(entry.outputName)
        Text(displayPath)
          .dsText(DS.Typography.microRegular)
          .foregroundStyle(DS.Color.textFaint)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(displayPath)
        meta
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if isFound {
        Button(action: reveal) {
          Image(systemName: "folder")
        }
        .buttonStyle(GhostIconButtonStyle())
        .help("Show in Finder")
        .accessibilityLabel("Show in Finder")
      } else {
        NotFoundBadge()
      }
    }
    .padding(DS.Space.s2_5)
    .background(DS.Color.bgCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.lg)
        .strokeBorder(DS.Color.borderSubtle, lineWidth: DS.Size.hairline)
    )
    .opacity(isFound ? 1 : DS.Opacity.unavailable)
    .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    .onDrag { dragProvider }
    .contextMenu {
      if isFound {
        Button("Show in Finder", action: reveal)
      }
      Button("Copy Path") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.output.path, forType: .string)
      }
      Divider()
      Button("Remove from History", role: .destructive, action: onRemove)
    }
    .accessibilityElement(children: .contain)
  }

  private var meta: some View {
    HStack(spacing: DS.Space.s1) {
      Text(Formatters.bytes(entry.outputBytes))
        .dsText(DS.Typography.label)
        .foregroundStyle(DS.Color.textPrimary)
      if let saved = entry.savedPercent {
        SavedBadge(percent: saved)
      }
      Text("· \(when)")
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
    }
    .monospacedDigit()
  }

  private var displayPath: String {
    (entry.output.path as NSString).abbreviatingWithTildeInPath
  }

  /// Same drag-to-upload affordance as a finished queue row, but only while the file still exists.
  private var dragProvider: NSItemProvider {
    if isFound, let provider = NSItemProvider(contentsOf: entry.output) {
      return provider
    }
    return NSItemProvider()
  }

  private func reveal() {
    NSWorkspace.shared.activateFileViewerSelecting([entry.output])
  }
}

struct HistoryEmptyState: View {
  var body: some View {
    VStack(spacing: DS.Space.s3) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: DS.Size.emptyGlyph))
        .foregroundStyle(DS.Color.gold500)
      Text("No exports yet")
        .dsText(DS.Typography.heading)
        .foregroundStyle(DS.Color.textPrimary)
      Text("Compressed and edited videos show up here, so you can find them again.")
        .dsText(DS.Typography.body)
        .foregroundStyle(DS.Color.textMuted)
        .multilineTextAlignment(.center)
    }
    .padding(DS.Space.s8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// "23:16" for today/yesterday (the group already says which day), weekday for this week, date for older.
enum HistoryDateLabel {
  static func text(for date: Date, group: HistoryGroup, now: Date = Date(), calendar: Calendar = .current) -> String {
    switch group {
    case .today, .yesterday:
      return date.formatted(date: .omitted, time: .shortened)
    case .previousWeek:
      return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    case .older:
      let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
      return sameYear
        ? date.formatted(.dateTime.month(.abbreviated).day())
        : date.formatted(.dateTime.month(.abbreviated).day().year())
    }
  }
}

#Preview("History") {
  HistoryView()
    .environment(HistoryStore(file: nil))
}
