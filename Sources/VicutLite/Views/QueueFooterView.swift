import SwiftUI
import VicutCore

/// Bottom bar of the Queue: active compression preset, session savings, Settings, Add videos.
struct QueueFooterView: View {
  @Environment(SettingsStore.self) private var settings
  let savedBytes: Int64
  let onAddVideos: () -> Void
  /// Opens the in-window Settings page.
  let onOpenSettings: () -> Void
  @State private var showPresets = false

  var body: some View {
    HStack(spacing: DS.Space.s3) {
      presetChip
      savedLabel
      Spacer(minLength: DS.Space.s2)
      Button(action: onOpenSettings) {
        DSIcon("gearshape", size: DS.Size.glyphLarge)
      }
      .buttonStyle(DSIconButtonStyle(size: .large, bordered: true))
      .help("Settings")
      .accessibilityLabel("Settings")
      Button(action: onAddVideos) {
        Label("Add videos", systemImage: "plus")
      }
      .buttonStyle(DSPrimaryButtonStyle(size: .large, glow: true))
      .keyboardShortcut("o")
    }
    .padding(.horizontal, DS.Space.s4)
    .frame(height: DS.Size.footer)
    .background(DS.Color.bgChrome)
    .overlay(alignment: .top) {
      Rectangle().fill(DS.Color.borderSubtle).frame(height: DS.Stroke.hairline)
    }
  }

  private var presetChip: some View {
    let current = settings.settings
    return Button { showPresets.toggle() } label: {
      HStack(spacing: DS.Space.s2) {
        DSIcon("slider.horizontal.3", size: DS.Size.glyphSmall)
          .foregroundStyle(DS.Color.gold500)
        (Text(QueueFormat.target(current)).font(DS.Typography.label.font).foregroundStyle(DS.Color.gold300)
          + Text(" · \(QueueFormat.resolution(current)) · \(QueueFormat.fps(current))"))
          .lineLimit(1)
        DSIcon("chevron.down", size: DS.Size.glyphSmall)
          .foregroundStyle(DS.Color.textMuted)
      }
    }
    .buttonStyle(DSChipButtonStyle())
    .help("Compression preset")
    .popover(isPresented: $showPresets, arrowEdge: .top) {
      PresetPopover {
        showPresets = false
        onOpenSettings()
      }
    }
  }

  @ViewBuilder private var savedLabel: some View {
    if savedBytes > 0 {
      (Text("Saved ") + Text(Formatters.bytes(savedBytes)).font(DS.Typography.label.font)
        .foregroundStyle(DS.Color.textPrimary) + Text(" this session"))
        .dsText(DS.Typography.caption)
        .foregroundStyle(DS.Color.textMuted)
        .lineLimit(1)
    }
  }
}

/// Quick switch for the three settings people change most; the rest live in Settings.
private struct PresetPopover: View {
  @Environment(SettingsStore.self) private var store
  let onAllSettings: () -> Void

  private static let targets: [(String, Int64?)] = [
    ("5 MB", 5_000_000),
    ("10 MB · GitHub free", CompressSettings.githubLimitBytes),
    ("25 MB", 25_000_000),
    ("No limit", nil)
  ]
  private static let resolutions: [(String, Int?)] = [("1080p", 1920), ("720p", 1280), ("Original", nil)]
  private static let frameRates: [Int] = [15, 30, 60]

  var body: some View {
    @Bindable var store = store
    VStack(alignment: .leading, spacing: DS.Space.s3) {
      section("Target size") {
        ForEach(Self.targets, id: \.0) { option in
          optionRow(option.0, isOn: store.settings.targetBytes == option.1) {
            store.settings.targetBytes = option.1
          }
        }
      }
      section("Max resolution") {
        ForEach(Self.resolutions, id: \.0) { option in
          optionRow(option.0, isOn: store.settings.maxDimension == option.1) {
            store.settings.maxDimension = option.1
          }
        }
      }
      section("Frame rate") {
        ForEach(Self.frameRates, id: \.self) { fps in
          optionRow("\(fps) fps", isOn: store.settings.fpsCap == fps) {
            store.settings.fpsCap = fps
          }
        }
      }
      Rectangle().fill(DS.Color.borderSubtle).frame(height: DS.Stroke.hairline)
      Button(action: onAllSettings) {
        Text("All settings…").frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(DSGhostButtonStyle(size: .small, bordered: false))
    }
    .padding(DS.Space.s3)
    .frame(width: DS.Size.presetPopoverWidth)
    .presentationBackground(DS.Color.bgRaised)
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.s0_5) {
      Text(title)
        .dsText(DS.Typography.overline)
        .foregroundStyle(DS.Color.textMuted)
        .padding(.horizontal, DS.Space.s2)
        .padding(.bottom, DS.Space.s1)
      content()
    }
  }

  private func optionRow(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: DS.Space.s2) {
        Text(label).dsText(DS.Typography.body)
        Spacer(minLength: 0)
        if isOn {
          DSIcon("checkmark", size: DS.Size.glyphSmall)
            .foregroundStyle(DS.Color.gold500)
        }
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(DSMenuItemButtonStyle(isOn: isOn))
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}

/// Selection-mode bar that replaces the footer: count, space freed, Cancel, Delete originals.
struct SelectionBarView: View {
  let selectedCount: Int
  let freedBytes: Int64
  let onCancel: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: DS.Space.s3) {
      Text("\(selectedCount) selected")
        .dsText(DS.Typography.bodyBold)
        .foregroundStyle(DS.Color.textPrimary)
      if selectedCount > 0 {
        Text("Deleting originals frees \(Formatters.bytes(freedBytes))")
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textMuted)
          .lineLimit(1)
      }
      Spacer(minLength: DS.Space.s2)
      Button("Cancel", action: onCancel)
        .buttonStyle(DSGhostButtonStyle(size: .large))
      Button(action: onDelete) {
        Label("Delete originals", systemImage: "trash")
      }
      .buttonStyle(DSDangerButtonStyle())
      .disabled(selectedCount == 0)
    }
    .padding(.horizontal, DS.Space.s4)
    .frame(height: DS.Size.footer)
    .background(DS.Color.bgSelectionBar)
    .overlay(alignment: .top) {
      Rectangle().fill(DS.Color.borderGold).frame(height: DS.Stroke.hairline)
    }
  }
}

/// Confirms moving originals to the Trash; outputs are never touched.
struct TrashOriginalsDialog: View {
  let jobs: [Job]
  let onCancel: () -> Void
  let onConfirm: () -> Void

  private var freedBytes: Int64 {
    jobs.reduce(0) { $0 + $1.originalBytes }
  }

  var body: some View {
    DSDialog {
      Text(jobs.count == 1 ? "Move original to Trash?" : "Move \(jobs.count) originals to Trash?")
        .dsText(DS.Typography.title)
        .foregroundStyle(DS.Color.textPrimary)
      (Text("The compressed and edited files stay where they are. Originals go to the Trash, "
        + "so you can still restore them. Frees ")
        + Text(Formatters.bytes(freedBytes)).font(DS.Typography.bodyBold.font).foregroundStyle(DS.Color.gold300)
        + Text("."))
        .dsText(DS.Typography.body)
        .foregroundStyle(DS.Color.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      ScrollView {
        VStack(spacing: DS.Space.s1) {
          ForEach(jobs) { job in
            HStack(spacing: DS.Space.s2) {
              Text(job.input.lastPathComponent)
                .foregroundStyle(DS.Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
              Spacer(minLength: 0)
              Text(Formatters.bytes(job.originalBytes))
                .foregroundStyle(DS.Color.textMuted)
            }
            .dsText(DS.Typography.label)
            .padding(.vertical, DS.Space.s2)
            .padding(.horizontal, DS.Space.s3)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.Color.bgInset))
            .overlay(
              RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Color.borderDefault, lineWidth: DS.Stroke.hairline)
            )
          }
        }
      }
      .frame(maxHeight: DS.Size.dialogListMax)
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: DS.Space.s2) {
        Spacer()
        Button("Cancel", action: onCancel)
          .buttonStyle(DSGhostButtonStyle(size: .dialog))
          .keyboardShortcut(.cancelAction)
        Button("Move to Trash", action: onConfirm)
          .buttonStyle(DSDangerButtonStyle(size: .dialog))
      }
      .padding(.top, DS.Space.s1)
    }
  }
}
