import SwiftUI
import VicutCore

struct EditorView: View {
  @Environment(JobQueue.self) private var queue
  @Environment(SettingsStore.self) private var settings
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismiss) private var dismiss
  @State private var model: EditorModel
  @State private var showExportOptions = false
  @State private var isEditMenuOpen = false

  /// 1 s steps feel right for arrow-key scrubbing; finer control is the timeline drag.
  private static let arrowStep = 1.0
  private static let speedKeys: [Double] = [2, 4, 8]

  init(url: URL) {
    _model = State(initialValue: EditorModel(url: url))
  }

  var body: some View {
    content
      .frame(minWidth: DS.Size.editorMinWidth, minHeight: DS.Size.editorMinHeight)
      .background(DS.Color.bgApp)
      .preferredColorScheme(.dark)
      .navigationTitle(model.url.lastPathComponent)
      .toolbar { titleBar }
      .toolbarBackground(DS.Color.bgChrome, for: .windowToolbar)
      .toolbarBackground(.visible, for: .windowToolbar)
      .modifier(HiddenWindowTitle())
      .task { await model.load() }
      .onDisappear { model.teardown() }
  }

  @ViewBuilder
  private var content: some View {
    if let error = model.loadError {
      ContentUnavailableView("Can't open video", systemImage: "exclamationmark.triangle", description: Text(error))
    } else {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          stage
          if model.spansPanel == .pinned {
            SpansPanelSlot(model: model, mode: .pinned)
          }
        }
        .frame(maxHeight: .infinity)
        transportBar
        timelineSection
      }
      .overlayPreferenceValue(EditMenuAnchorKey.self) { anchor in
        editMenuOverlay(anchor)
      }
      .overlay {
        if let pending = model.pendingReplace {
          OverlapDialog(
            pending: pending,
            onCancel: { model.cancelPendingReplace() },
            onConfirm: { model.confirmPendingReplace() }
          )
        }
      }
      .background(shortcuts)
    }
  }

  // MARK: Title bar

  @ToolbarContentBuilder
  private var titleBar: some ToolbarContent {
    EditorToolbarItem(placement: .principal) {
      HStack(spacing: DS.Space.s2) {
        Image(systemName: "scissors")
          .font(.system(size: DS.Size.icon, weight: .semibold))
          .foregroundStyle(DS.Color.gold500)
        Text(model.url.lastPathComponent)
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.textPrimary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .help(model.url.lastPathComponent)
    }
    EditorToolbarItem(placement: .automatic) {
      Text(Formatters.duration(model.duration))
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .monospacedDigit()
        .padding(.horizontal, DS.Space.s2)
        .accessibilityLabel("Clip length \(Formatters.duration(model.duration))")
    }
  }

  // MARK: Stage

  private var stage: some View {
    ZStack {
      DS.Color.bgStage
      PlayerView(player: model.player)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {
      previewChip.padding(DS.Space.s3_5)
    }
    .overlay(alignment: .bottom) {
      if let toast = model.toast {
        EditorKit.Toast(message: toast.message, isError: toast.isError)
          .padding(.horizontal, DS.Space.s6)
          .padding(.bottom, DS.Space.s3_5)
          .onTapGesture { model.dismissToast() }
          .transition(.opacity)
      }
    }
    .overlay(alignment: .trailing) {
      if model.spansPanel == .floating {
        SpansPanelSlot(model: model, mode: .floating)
          .padding(DS.Space.s3)
      }
    }
    .animation(.easeOut, value: model.toast)
    .clipped()
  }

  private var previewChip: some View {
    Button {
      model.previewEdits.toggle()
    } label: {
      EditorKit.Pill(
        text: model.previewEdits ? "Preview edits · On" : "Preview edits · Off",
        foreground: model.previewEdits ? DS.Color.gold300 : DS.Color.textMuted,
        fill: DS.Color.bgToast,
        radius: DS.Radius.span
      )
    }
    .buttonStyle(.plain)
    .help("Skip cut parts and fast-forward sped-up parts while playing, so playback matches the export")
    .accessibilityAddTraits(model.previewEdits ? .isSelected : [])
  }

  // MARK: Transport + export

  private var transportBar: some View {
    HStack(spacing: DS.Space.s3) {
      playButton
      HStack(spacing: DS.Space.s1_5) {
        Text(Formatters.duration(model.currentTime))
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.textPrimary)
        Text("/ \(Formatters.duration(model.duration))")
          .dsText(DS.Typography.body)
          .foregroundStyle(DS.Color.textFaint)
      }
      .monospacedDigit()
      .accessibilityElement(children: .combine)

      Spacer(minLength: DS.Space.s3)

      HStack(alignment: .firstTextBaseline, spacing: DS.Space.s1_5) {
        Text("Output")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
        Text(model.outputDuration.map(Formatters.duration) ?? "--:--")
          .dsText(DS.Typography.heading)
          .foregroundStyle(DS.Color.gold300)
          .monospacedDigit()
      }
      .accessibilityElement(children: .combine)

      EditorKit.Pill(text: sizeLimit)
        .help("Size limit for a compressed export (Settings)")

      Button("Cancel") {
        model.teardown()
        dismiss()
      }
      .buttonStyle(EditorKit.GhostButtonStyle())
      .padding(.leading, DS.Space.s1_5)

      Button {
        showExportOptions = true
      } label: {
        HStack(spacing: DS.Space.s2) {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: DS.Size.iconSmall, weight: .bold))
          Text("Export")
        }
      }
      .buttonStyle(EditorKit.PrimaryButtonStyle())
      .keyboardShortcut("e", modifiers: .command)
      .disabled(model.outputDuration == nil)
      .help("Export… (⌘E)")
      .popover(isPresented: $showExportOptions, arrowEdge: .top) {
        exportOptions
      }
    }
    .padding(.horizontal, DS.Space.s4)
    .frame(height: DS.Size.transportBar)
    .background(DS.Color.bgChrome)
    .overlay(alignment: .top) { divider }
  }

  private var playButton: some View {
    Button {
      model.togglePlay()
    } label: {
      Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
        .font(.system(size: DS.Size.icon, weight: .bold))
        .foregroundStyle(DS.Color.onGold)
        .frame(width: DS.Size.playButton, height: DS.Size.playButton)
        .background(Circle().fill(DS.Color.gold500))
        .overlay(Circle().stroke(DS.Color.goldHalo, lineWidth: DS.Size.playHalo).padding(-DS.Size.playHalo / 2))
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .keyboardShortcut(.space, modifiers: [])
    .help("Play / Pause (Space)")
    .accessibilityLabel(model.isPlaying ? "Pause preview" : "Play preview")
  }

  private var sizeLimit: String {
    settings.settings.targetBytes.map { "≤ \(Formatters.bytes($0))" } ?? "No size limit"
  }

  // MARK: Timeline

  private var timelineSection: some View {
    VStack(spacing: DS.Space.s2) {
      TimelineHeaderView(model: model, isEditMenuOpen: $isEditMenuOpen)
      EditTimelineView(model: model)
    }
    .padding(.horizontal, DS.Space.s4)
    .padding(.top, DS.Space.s2)
    .padding(.bottom, DS.Space.s3)
    .background(DS.Color.bgInset)
    .overlay(alignment: .top) { divider }
  }

  private var divider: some View {
    Rectangle()
      .fill(DS.Color.borderSubtle)
      .frame(height: DS.Size.hairline)
  }

  /// Drawn at window level so a click anywhere outside the menu can close it.
  @ViewBuilder
  private func editMenuOverlay(_ anchor: Anchor<CGRect>?) -> some View {
    if isEditMenuOpen, let anchor {
      GeometryReader { proxy in
        let button = proxy[anchor]
        ZStack(alignment: .topLeading) {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture { isEditMenuOpen = false }
          EditSpanMenu(model: model) { isEditMenuOpen = false }
            .frame(height: max(button.minY - DS.Space.s1_5, 0), alignment: .bottomLeading)
            .offset(x: min(button.minX, max(proxy.size.width - DS.Size.menuWidth - DS.Space.s4, 0)))
        }
      }
    }
  }

  // MARK: Keyboard

  /// Shortcuts without a visible button. Hidden buttons still receive key equivalents.
  private var shortcuts: some View {
    ZStack {
      shortcut(.leftArrow) { model.step(by: -Self.arrowStep) }
      shortcut(.rightArrow) { model.step(by: Self.arrowStep) }
      shortcut("i") { model.markIn() }
      shortcut("o") { model.markOut() }
      shortcut("c") { model.apply(.cut) }
      shortcut("k") { model.apply(.keep) }
      ForEach(Self.speedKeys, id: \.self) { factor in
        shortcut(KeyEquivalent(Character(String(Int(factor))))) { model.apply(.speed(factor)) }
      }
      if isEditMenuOpen {
        shortcut(.escape) { isEditMenuOpen = false }
      }
    }
    .frame(width: 0, height: 0)
    .opacity(0)
    .accessibilityHidden(true)
    .disabled(model.pendingReplace != nil)
  }

  private func shortcut(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
    Button("", action: action).keyboardShortcut(key, modifiers: [])
  }

  // MARK: Export

  private var exportOptions: some View {
    VStack(alignment: .leading, spacing: DS.Space.s3) {
      Text("Export as .mp4")
        .dsText(DS.Typography.heading)
        .foregroundStyle(DS.Color.textPrimary)
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
    .padding(DS.Space.s4)
    .frame(width: DS.Size.exportPopover)
    .background(DS.Color.bgRaised)
  }

  private func exportChoice(title: String, detail: String, systemImage: String, fullQuality: Bool) -> some View {
    Button {
      export(fullQuality: fullQuality)
    } label: {
      EditorKit.HoverBody { hovering in
        HStack(spacing: DS.Space.s3) {
          Image(systemName: systemImage)
            .font(.system(size: DS.Size.icon, weight: .semibold))
            .foregroundStyle(DS.Color.gold500)
            .frame(width: DS.Size.exportChoiceIcon)
          VStack(alignment: .leading, spacing: DS.Space.s0_5) {
            Text(title)
              .dsText(DS.Typography.label)
              .foregroundStyle(DS.Color.textPrimary)
            Text(detail)
              .dsText(DS.Typography.caption)
              .foregroundStyle(DS.Color.textMuted)
          }
          Spacer()
        }
        .padding(DS.Space.s3)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(hovering ? DS.Color.bgHover : DS.Color.bgInset))
        .overlay(
          RoundedRectangle(cornerRadius: DS.Radius.lg)
            .strokeBorder(hovering ? DS.Color.borderGold : DS.Color.borderDefault, lineWidth: DS.Size.hairline)
        )
        .contentShape(Rectangle())
      }
    }
    .buttonStyle(.plain)
  }

  private func export(fullQuality: Bool) {
    showExportOptions = false
    model.teardown()
    queue.enqueueExport(model.url, marks: model.marks, fullQuality: fullQuality)
    openWindow(id: WindowID.main)
    dismiss()
  }
}

/// The file name is drawn centred in the toolbar; hide the system title so it isn't shown twice.
private struct HiddenWindowTitle: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 15, *) {
      content.toolbar(removing: .title)
    } else {
      content.background(EditorKit.WindowConfigurator { $0.titleVisibility = .hidden })
    }
  }
}

/// Toolbar item without the macOS 26 glass capsule, so title-bar text sits on the chrome colour.
private struct EditorToolbarItem<Content: View>: ToolbarContent {
  let placement: ToolbarItemPlacement
  @ViewBuilder let content: Content

  var body: some ToolbarContent {
    if #available(macOS 26, *) {
      ToolbarItem(placement: placement) { content }
        .sharedBackgroundVisibility(.hidden)
    } else {
      ToolbarItem(placement: placement) { content }
    }
  }
}
