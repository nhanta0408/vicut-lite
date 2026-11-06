import CoreGraphics
import Foundation
import Testing
@testable import VicutCore

struct VideoFilesTests {
  @Test func acceptsVideoExtensionsCaseInsensitively() {
    #expect(VideoFiles.isSupported(URL(fileURLWithPath: "/tmp/a.MOV")))
    #expect(VideoFiles.isSupported(URL(fileURLWithPath: "/tmp/b.mp4")))
    #expect(!VideoFiles.isSupported(URL(fileURLWithPath: "/tmp/c.png")))
    #expect(!VideoFiles.isSupported(URL(fileURLWithPath: "/tmp/folder")))
  }

  @Test func rejectsRemoteURLs() throws {
    let remote = try #require(URL(string: "https://example.com/clip.mp4"))
    #expect(!VideoFiles.isSupported(remote))
  }
}

struct DragSessionDetectorTests {
  private let video = URL(fileURLWithPath: "/tmp/clip.mov")
  private let image = URL(fileURLWithPath: "/tmp/shot.png")

  @Test func ignoresUnchangedPasteboard() {
    var detector = DragSessionDetector(changeCount: 5)
    var reads = 0
    let result = detector.videosForNewDrag(changeCount: 5) {
      reads += 1
      return [video]
    }
    #expect(result == nil)
    #expect(reads == 0)
  }

  @Test func reportsNewDragWithVideosOnce() {
    var detector = DragSessionDetector(changeCount: 5)
    #expect(detector.videosForNewDrag(changeCount: 6) { [video, image] } == [video])
    #expect(detector.videosForNewDrag(changeCount: 6) { [video] } == nil)
    #expect(detector.seenChangeCount == 6)
  }

  @Test func ignoresDragsWithoutVideos() {
    var detector = DragSessionDetector(changeCount: 1)
    #expect(detector.videosForNewDrag(changeCount: 2) { [image] } == nil)
    #expect(detector.seenChangeCount == 2)
  }

  @Test func retriesWhilePasteboardIsStillEmpty() {
    var detector = DragSessionDetector(changeCount: 1)
    #expect(detector.videosForNewDrag(changeCount: 2) { nil } == nil)
    #expect(detector.seenChangeCount == 1)
    #expect(detector.videosForNewDrag(changeCount: 2) { [video] } == [video])
  }
}

struct DropZonePlacementTests {
  private let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
  private let side = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

  @Test func picksScreenUnderPointer() {
    #expect(DropZonePlacement.screenIndex(containing: CGPoint(x: 100, y: 100), screens: [main, side]) == 0)
    #expect(DropZonePlacement.screenIndex(containing: CGPoint(x: 2000, y: 500), screens: [main, side]) == 1)
  }

  @Test func fallsBackToFirstScreen() {
    #expect(DropZonePlacement.screenIndex(containing: CGPoint(x: -50, y: -50), screens: [main, side]) == 0)
    #expect(DropZonePlacement.screenIndex(containing: .zero, screens: []) == nil)
  }

  @Test func sitsInBottomRightCorner() {
    let visible = CGRect(x: 1440, y: 70, width: 1920, height: 985)
    let frame = DropZonePlacement.frame(size: CGSize(width: 280, height: 150), in: visible, margin: 20)
    #expect(frame == CGRect(x: 1440 + 1920 - 20 - 280, y: 90, width: 280, height: 150))
  }

  @Test func shrinksOnTinyScreens() {
    let visible = CGRect(x: 0, y: 0, width: 200, height: 100)
    let frame = DropZonePlacement.frame(size: CGSize(width: 280, height: 150), in: visible, margin: 10)
    #expect(frame == CGRect(x: 10, y: 10, width: 180, height: 80))
  }

  @Test func slidesToTheRight() {
    let frame = CGRect(x: 100, y: 20, width: 50, height: 40)
    #expect(DropZonePlacement.slidFrame(frame, by: 30) == CGRect(x: 130, y: 20, width: 50, height: 40))
  }
}

struct AppPresenceTests {
  @Test func defaultsShowEverything() {
    let presence = AppPresence.default
    #expect(presence.showInMenuBar && presence.showInDock && presence.dropZoneWhileDragging)
    #expect(!presence.terminatesAfterLastWindowClosed)
  }

  @Test func dockStaysWhenMenuBarIsOff() {
    let presence = AppPresence(showInMenuBar: false, showInDock: false, dropZoneWhileDragging: true)
    #expect(presence.effectiveShowInDock)
    #expect(!presence.canHideDock)
    #expect(presence.terminatesAfterLastWindowClosed)
  }

  @Test func dockHidesOnlyWithMenuBar() {
    let presence = AppPresence(showInMenuBar: true, showInDock: false, dropZoneWhileDragging: false)
    #expect(!presence.effectiveShowInDock)
    #expect(!presence.terminatesAfterLastWindowClosed)
  }

  @Test func dockIconFollowsOpenWindowsWhenHidden() {
    let hidden = AppPresence(showInMenuBar: true, showInDock: false, dropZoneWhileDragging: true)
    #expect(hidden.showsInDock(hasOpenWindows: true))
    #expect(!hidden.showsInDock(hasOpenWindows: false))
    #expect(AppPresence.default.showsInDock(hasOpenWindows: false))
  }
}
