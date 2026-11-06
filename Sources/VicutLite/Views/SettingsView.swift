import SwiftUI
import VicutCore

/// Full-window Settings page bound to `SettingsStore`. Navigation (breadcrumb, tab bar) belongs to the host.
struct SettingsView: View {
  @Environment(SettingsStore.self) private var store
  /// Called on Escape so the host can return to the previous page; nil disables it.
  var onBack: (() -> Void)?

  init(onBack: (() -> Void)? = nil) {
    self.onBack = onBack
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(spacing: DS.Space.s5) {
          compression
          audio
          output
        }
        .padding(.horizontal, DS.Space.s5)
        .padding(.top, DS.Space.s3)
        .padding(.bottom, DS.Space.s6)
      }
      .scrollContentBackground(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.Color.bgApp)
    .onExitCommand(perform: onBack)
  }

  private var header: some View {
    HStack(alignment: .center, spacing: DS.Space.s3) {
      Text("Settings")
        .dsText(DS.Typography.page)
        .foregroundStyle(DS.Color.textPrimary)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: DS.Space.s2)
      Button(action: store.restoreDefaults) {
        HStack(spacing: DS.Space.s1_5) {
          Image(systemName: "arrow.counterclockwise")
            .font(.system(size: DS.Size.glyphSm))
          Text("Restore defaults")
        }
      }
      .buttonStyle(DSGhostButtonStyle(size: .medium, quiet: true))
      .disabled(store.isDefault)
      .help("Reset every setting to its default value")
    }
    .padding(.horizontal, DS.Space.s5)
    .padding(.top, DS.Space.s5)
    .padding(.bottom, DS.Space.s1)
  }

  private var compression: some View {
    @Bindable var store = store
    return SettingsSection(title: "Compression") {
      SettingsRow(label: "Target size", hint: "Output stays under this size.") {
        SegmentedControl(
          title: "Target size",
          options: SettingsOptions.target,
          selection: $store.settings.targetBytes,
          width: DS.Size.segmentWide
        )
      }
      SettingsDivider()
      SettingsRow(label: "Max resolution", hint: "Longest side is scaled down to this.") {
        SegmentedControl(
          title: "Max resolution",
          options: SettingsOptions.resolution,
          selection: $store.settings.maxDimension
        )
      }
      SettingsDivider()
      SettingsRow(label: "Frame rate", hint: "Frame rate cap.") {
        SegmentedControl(title: "Frame rate", options: SettingsOptions.fps, selection: $store.settings.fpsCap)
      }
      SettingsDivider()
      SettingsRow(
        label: "Encoder",
        hint: "Fast uses every CPU core. Light uses Apple's media engine: under one core, a bit slower, slightly larger files."
      ) {
        SegmentedControl(title: "Encoder", options: SettingsOptions.encoder, selection: encoderBinding)
      }
    }
  }

  /// `.fast` is stored as nil so untouched settings still compare equal to the defaults.
  private var encoderBinding: Binding<EncoderMode> {
    Binding(
      get: { store.settings.resolvedEncoder },
      set: { store.settings.encoder = $0 == .fast ? nil : $0 }
    )
  }

  private var audio: some View {
    @Bindable var store = store
    return SettingsSection(title: "Audio") {
      SettingsRow(label: "Audio", hint: "Audio track in the output file.") {
        SegmentedControl(title: "Audio", options: SettingsOptions.audio, selection: $store.settings.audio)
      }
      SettingsDivider()
      SettingsToggleRow(
        label: "Mute sped-up parts",
        hint: "Silence the audio of 2× speed spans instead of playing it chipmunk-fast.",
        isOn: $store.settings.muteSpedUpAudio
      )
    }
  }

  private var output: some View {
    @Bindable var store = store
    return SettingsSection(title: "Output") {
      SettingsRow(label: "File name suffix", hint: "Saved next to the original file.") {
        InsetTextField(title: "File name suffix", text: $store.outputSuffix)
      }
      SettingsDivider()
      OutputNamePreview(suffix: store.settings.outputSuffix)
    }
  }
}

/// "name.mov → name-vicut.mp4" with the suffix in gold.
private struct OutputNamePreview: View {
  let suffix: String

  var body: some View {
    HStack(spacing: DS.Space.s2) {
      Text("name.mov")
        .foregroundStyle(DS.Color.textMuted)
      Image(systemName: "arrow.right")
        .font(.system(size: DS.Size.glyphXs, weight: .semibold))
        .foregroundStyle(DS.Color.textFaint)
      Text("name\(Text(suffix).foregroundStyle(DS.Color.gold500)).mp4")
        .foregroundStyle(DS.Color.textPrimary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .dsText(DS.Typography.caption)
    .padding(.vertical, DS.Space.s2_5)
    .padding(.horizontal, DS.Space.s4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .help("Example output file name")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Example: name.mov becomes name\(suffix).mp4")
  }
}

/// Choices shown in Settings; values come from `CompressSettings` so the encoder and UI agree.
enum SettingsOptions {
  static let target: [SegmentOption<Int64?>] = [
    SegmentOption(value: CompressSettings.smallTargetBytes, label: "5 MB"),
    SegmentOption(value: CompressSettings.defaultTargetBytes, label: "10 MB", hint: "Default"),
    SegmentOption(value: CompressSettings.largeTargetBytes, label: "25 MB"),
    SegmentOption(value: nil, label: "No limit", hint: "Quality only, no size target")
  ]

  static let resolution: [SegmentOption<Int?>] = [
    SegmentOption(value: CompressSettings.maxDimension1080p, label: "1080p", hint: "\(CompressSettings.maxDimension1080p) px"),
    SegmentOption(value: CompressSettings.maxDimension720p, label: "720p", hint: "\(CompressSettings.maxDimension720p) px"),
    SegmentOption(value: nil, label: "Original")
  ]

  static let fps: [SegmentOption<Int>] = CompressSettings.fpsPresets.map {
    SegmentOption(value: $0, label: "\($0) fps")
  }

  static let encoder: [SegmentOption<EncoderMode>] = [
    SegmentOption(value: .fast, label: "Fast", hint: "x264 on every CPU core · smallest files"),
    SegmentOption(value: .light, label: "Light", hint: "Apple hardware encoder · keeps the Mac cool and responsive")
  ]

  static let audio: [SegmentOption<AudioMode>] = [
    SegmentOption(value: .keep, label: "Stereo", hint: "Keep, stereo 128k"),
    SegmentOption(value: .mono, label: "Mono 64k"),
    SegmentOption(value: .strip, label: "Remove")
  ]
}

#Preview("Settings") {
  SettingsView()
    .environment(SettingsStore(defaults: UserDefaults(suiteName: "preview.settings") ?? .standard))
    .frame(width: DS.Size.settingsWindowWidth, height: DS.Size.settingsWindowHeight)
}
