import SwiftUI
import VicutCore

struct SettingsView: View {
  @Environment(SettingsStore.self) private var store

  var body: some View {
    @Bindable var store = store
    Form {
      Picker("Target size", selection: $store.settings.targetBytes) {
        Text("5 MB").tag(Int64?.some(5_000_000))
        Text("10 MB (GitHub free)").tag(Int64?.some(CompressSettings.githubLimitBytes))
        Text("25 MB").tag(Int64?.some(25_000_000))
        Text("No limit (quality only)").tag(Int64?.none)
      }
      Picker("Max resolution", selection: $store.settings.maxDimension) {
        Text("1080p (1920 px)").tag(Int?.some(1920))
        Text("720p (1280 px)").tag(Int?.some(1280))
        Text("Original").tag(Int?.none)
      }
      Picker("Frame rate", selection: $store.settings.fpsCap) {
        Text("15 fps").tag(15)
        Text("30 fps").tag(30)
        Text("60 fps").tag(60)
      }
      Picker("Audio", selection: $store.settings.audio) {
        Text("Keep (stereo 128k)").tag(AudioMode.keep)
        Text("Mono 64k").tag(AudioMode.mono)
        Text("Remove").tag(AudioMode.strip)
      }
      Toggle("Mute sped-up parts", isOn: $store.settings.muteSpedUpAudio)
      TextField("File name suffix", text: $store.settings.outputSuffix)
      Text("Output is saved next to the original as “name\(store.settings.outputSuffix).mp4”.")
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Restore defaults") { store.settings = .default }
      }
    }
    .formStyle(.grouped)
    .frame(width: 440)
    .padding(.vertical, 8)
  }
}
