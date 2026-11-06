import Foundation
import Observation
import VicutCore

@MainActor
@Observable
final class SettingsStore {
  private static let defaultsKey = "compressSettings"

  var settings: CompressSettings {
    didSet { persist() }
  }

  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.defaultsKey),
       let stored = try? JSONDecoder().decode(CompressSettings.self, from: data) {
      settings = stored
    } else {
      settings = .default
    }
  }

  var summary: String {
    let target = settings.targetBytes.map { Formatters.bytes($0) } ?? "No size limit"
    let resolution = settings.maxDimension.map { "≤\($0)px" } ?? "Original size"
    return "\(target) · \(resolution) · \(settings.fpsCap) fps"
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(settings) {
      defaults.set(data, forKey: Self.defaultsKey)
    }
  }
}
