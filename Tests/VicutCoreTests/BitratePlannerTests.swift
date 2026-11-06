import Foundation
import Testing
@testable import VicutCore

struct BitratePlannerTests {
  private func info(
    w: Int = 2880, h: Int = 1800, fps: Double = 60, duration: Double = 60,
    audio: Bool = false, codec: String = "h264", size: Int64 = 200_000_000
  ) -> MediaInfo {
    MediaInfo(
      duration: duration, width: w, height: h, fps: fps, hasAudio: audio,
      videoCodec: codec, formatName: "mov,mp4,m4a,3gp,3g2,mj2", sizeBytes: size
    )
  }

  @Test func sixtySecondsAtTenMegabytesIsAboutOnePointTwoMbps() {
    var settings = CompressSettings.default
    settings.audio = .strip
    let plan = BitratePlanner.plan(source: info(), outputDuration: 60, settings: settings, edited: false)
    let kbps = try? #require(plan.videoKbps)
    #expect(kbps == 1266)
    #expect(plan.fps == 30)
    #expect(plan.mode == .encode)
  }

  @Test func lowBitsPerPixelStepsResolutionDown() {
    var settings = CompressSettings.default
    settings.audio = .strip
    let plan = BitratePlanner.plan(source: info(duration: 120), outputDuration: 120, settings: settings, edited: false)
    #expect(plan.width == 1280)
    #expect(plan.height == 800)
  }

  @Test func shortClipKeeps1080pClassDimensions() {
    var settings = CompressSettings.default
    settings.audio = .strip
    let plan = BitratePlanner.plan(source: info(duration: 20), outputDuration: 20, settings: settings, edited: false)
    #expect(plan.width == 1920)
    #expect(plan.height == 1200)
  }

  @Test func audioBudgetIsSubtracted() {
    var settings = CompressSettings.default
    settings.audio = .mono
    let plan = BitratePlanner.plan(source: info(audio: true), outputDuration: 60, settings: settings, edited: false)
    #expect(plan.audioKbps == 64)
    #expect(plan.videoKbps == 1266 - 64)
  }

  @Test func audioIsDroppedWhenSourceHasNone() {
    let plan = BitratePlanner.plan(source: info(audio: false), outputDuration: 60, settings: .default, edited: false)
    #expect(plan.audioKbps == 0)
  }

  @Test func smallH264WithinLimitsIsRemuxed() {
    let src = info(w: 1280, h: 800, fps: 30, duration: 10, size: 3_000_000)
    let plan = BitratePlanner.plan(source: src, outputDuration: 10, settings: .default, edited: false)
    #expect(plan.mode == .remux)
  }

  @Test func editedClipIsNeverRemuxed() {
    let src = info(w: 1280, h: 800, fps: 30, duration: 10, size: 3_000_000)
    let plan = BitratePlanner.plan(source: src, outputDuration: 5, settings: .default, edited: true)
    #expect(plan.mode == .encode)
  }

  @Test func unlimitedTargetHasNoBitrate() {
    var settings = CompressSettings.default
    settings.targetBytes = nil
    let plan = BitratePlanner.plan(source: info(), outputDuration: 60, settings: settings, edited: false)
    #expect(plan.videoKbps == nil)
    #expect(plan.width == 1920)
  }

  @Test func originalResolutionKeepsEvenSourceDimensions() {
    var settings = CompressSettings.default
    settings.maxDimension = nil
    settings.targetBytes = nil
    let plan = BitratePlanner.plan(source: info(w: 1179, h: 2556), outputDuration: 60, settings: settings, edited: false)
    #expect(plan.width == 1178)
    #expect(plan.height == 2556)
  }

  @Test func portraitIsScaledByLongestSide() {
    var settings = CompressSettings.default
    settings.targetBytes = nil
    let plan = BitratePlanner.plan(source: info(w: 1179, h: 2556), outputDuration: 60, settings: settings, edited: false)
    #expect(plan.height == 1920)
    #expect(plan.width == 886)
  }

  @Test func fullQualityKeepsSourceResolutionFpsAndUsesHighQualityCrf() {
    let settings = CompressSettings.fullQuality(muteSpedUpAudio: true)
    let plan = BitratePlanner.plan(source: info(audio: true), outputDuration: 60, settings: settings, edited: true)
    #expect(plan.mode == .encode)
    #expect(plan.width == 2880)
    #expect(plan.height == 1800)
    #expect(plan.fps == 60)
    #expect(plan.videoKbps == nil)
    #expect(plan.audioChannels == nil)
    #expect(plan.crf == CompressSettings.fullQualityCrf)
  }

  @Test func compressedPlanUsesDefaultCrf() {
    let plan = BitratePlanner.plan(source: info(), outputDuration: 60, settings: .default, edited: false)
    #expect(plan.crf == EncodePlan.defaultCrf)
    #expect(plan.crf == CompressQuality.balanced.crf)
  }

  @Test(arguments: CompressQuality.allCases)
  func qualityLevelSetsCrf(quality: CompressQuality) {
    var settings = CompressSettings.default
    settings.quality = quality
    let plan = BitratePlanner.plan(source: info(), outputDuration: 60, settings: settings, edited: false)
    #expect(plan.crf == quality.crf)
  }

  @Test func explicitCrfWinsOverQuality() {
    var settings = CompressSettings.fullQuality(muteSpedUpAudio: true)
    settings.quality = .smaller
    let plan = BitratePlanner.plan(source: info(), outputDuration: 60, settings: settings, edited: false)
    #expect(plan.crf == CompressSettings.fullQualityCrf)
  }

  @Test func qualityLevelsGetSharperInOrder() {
    #expect(CompressQuality.smaller.crf > CompressQuality.balanced.crf)
    #expect(CompressQuality.balanced.crf > CompressQuality.sharper.crf)
  }

  @Test func settingsStoredBeforeCrfExistedStillDecode() throws {
    let legacy = #"{"targetBytes":10000000,"maxDimension":1920,"fpsCap":30,"audio":"mono","muteSpedUpAudio":true,"outputSuffix":"-vicut"}"#
    let decoded = try JSONDecoder().decode(CompressSettings.self, from: Data(legacy.utf8))
    #expect(decoded == .default)
  }
}

