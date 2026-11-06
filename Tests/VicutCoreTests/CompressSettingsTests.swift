import Foundation
import Testing
@testable import VicutCore

struct CompressSettingsTests {
  @Test func defaultIsDefault() {
    #expect(CompressSettings.default.isDefault)
  }

  @Test func anyChangeLeavesDefault() {
    var settings = CompressSettings.default
    settings.fpsCap = 60
    #expect(!settings.isDefault)
    settings.fpsCap = CompressSettings.default.fpsCap
    #expect(settings.isDefault)
    settings.outputSuffix = "-small"
    #expect(!settings.isDefault)
  }

  @Test func defaultUsesOfferedPresets() {
    let settings = CompressSettings.default
    #expect(CompressSettings.fpsPresets.contains(settings.fpsCap))
    #expect(settings.maxDimension == CompressSettings.maxDimension1080p)
    #expect(settings.targetBytes == CompressSettings.defaultTargetBytes)
  }

  @Test func sanitizedSuffixKeepsOrdinaryText() {
    #expect(CompressSettings.sanitizedSuffix("-vicut") == "-vicut")
    #expect(CompressSettings.sanitizedSuffix(" small (v2)") == " small (v2)")
    #expect(CompressSettings.sanitizedSuffix("-nén") == "-nén")
    #expect(CompressSettings.sanitizedSuffix("") == "")
  }

  @Test func sanitizedSuffixDropsPathAndControlCharacters() {
    #expect(CompressSettings.sanitizedSuffix("/../evil") == "..evil")
    #expect(CompressSettings.sanitizedSuffix("-a:b") == "-ab")
    #expect(CompressSettings.sanitizedSuffix("-a\nb\t") == "-ab")
  }

  @Test func sanitizedSuffixIsCapped() {
    let long = String(repeating: "x", count: CompressSettings.maxSuffixLength + 10)
    #expect(CompressSettings.sanitizedSuffix(long).count == CompressSettings.maxSuffixLength)
  }

  @Test func sanitizedSuffixStaysInSourceFolder() {
    let input = URL(fileURLWithPath: "/tmp/vicut-\(UUID().uuidString)/clip.mov")
    let output = OutputNamer.uniqueOutput(for: input, suffix: CompressSettings.sanitizedSuffix("/../x"))
    #expect(output.deletingLastPathComponent() == input.deletingLastPathComponent())
  }

  @Test func settingsSavedBeforeEncoderOptionDecodeAsFast() throws {
    var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(CompressSettings.default)) as? [String: Any] ?? [:]
    legacy.removeValue(forKey: "encoder")
    legacy.removeValue(forKey: "quality")
    let decoded = try JSONDecoder().decode(CompressSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(decoded.encoder == nil)
    #expect(decoded.resolvedEncoder == .fast)
    #expect(decoded.resolvedQuality == .balanced)
    #expect(decoded.isDefault)
  }

  @Test func fullQualityKeepsChosenEncoder() {
    #expect(CompressSettings.fullQuality(muteSpedUpAudio: true).resolvedEncoder == .fast)
    #expect(CompressSettings.fullQuality(muteSpedUpAudio: true, encoder: .light).resolvedEncoder == .light)
  }
}
