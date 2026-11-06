import Testing
@testable import VicutCore

struct TimelineSnapTests {
  @Test func snapsToNearestPointWithinThreshold() {
    #expect(Timeline.snap(10.6, to: [0, 10, 11, 60], within: 1) == 11)
    #expect(Timeline.snap(10.4, to: [0, 10, 11, 60], within: 1) == 10)
  }

  @Test func doesNotSnapBeyondThreshold() {
    #expect(Timeline.snap(25, to: [0, 10, 60], within: 1) == nil)
  }

  @Test func snapPointsAreSegmentBoundariesPlusEnds() {
    let marks = [Segment(start: 5, end: 10, action: .cut), Segment(start: 20, end: 30, action: .speed(4))]
    #expect(Timeline.snapPoints(marks: marks, duration: 60) == [0, 5, 10, 20, 30, 60])
  }

  @Test func snapThresholdIsOneSecondWhenZoomedOut() {
    // 30 minutes on 800px: 12px ≈ 27s, capped at 1s.
    #expect(Timeline.snapThreshold(visibleSpan: 1800, width: 800) == 1)
  }

  @Test func snapThresholdShrinksWhenZoomedIn() {
    // 5s on 800px: 12px = 0.075s, so a sub-second edit is still possible.
    let threshold = Timeline.snapThreshold(visibleSpan: 5, width: 800)
    #expect(abs(threshold - 0.075) < 0.0001)
  }
}

struct TimelineViewportTests {
  @Test func startsFittedToWholeClip() {
    let viewport = TimelineViewport(duration: 1800)
    #expect(viewport.start == 0)
    #expect(viewport.span == 1800)
    #expect(!viewport.isZoomed)
  }

  @Test func zoomKeepsAnchorAtSameScreenPosition() {
    var viewport = TimelineViewport(duration: 100)
    viewport.zoom(by: 4, anchor: 50)
    #expect(viewport.span == 25)
    #expect(viewport.start == 37.5)
    #expect(viewport.isZoomed)
  }

  @Test func zoomIsClampedToMinimumSpanAndWholeClip() {
    var viewport = TimelineViewport(duration: 100)
    viewport.zoom(by: 10_000, anchor: 0)
    #expect(viewport.span == TimelineViewport.minSpan)
    viewport.zoom(by: 0.000_1, anchor: 0)
    #expect(viewport.span == 100)
    #expect(viewport.start == 0)
  }

  @Test func panStaysInsideClip() {
    var viewport = TimelineViewport(duration: 100)
    viewport.zoom(by: 10, anchor: 0)
    viewport.pan(by: 500)
    #expect(viewport.start == 90)
    viewport.pan(by: -500)
    #expect(viewport.start == 0)
  }

  @Test func revealPagesToTimeOutsideView() {
    var viewport = TimelineViewport(duration: 100)
    viewport.zoom(by: 10, anchor: 0)
    viewport.reveal(50)
    #expect(viewport.start <= 50 && 50 <= viewport.end)
    let before = viewport
    viewport.reveal(viewport.start + 1)
    #expect(viewport == before)
  }

  @Test func fitFramesRangeWithPadding() {
    var viewport = TimelineViewport(duration: 1800)
    viewport.fit(600...605)
    #expect(viewport.start < 600 && viewport.end > 605)
    #expect(viewport.span < 10)
  }

  @Test func durationChangeResetsView() {
    var viewport = TimelineViewport(duration: 0)
    viewport.setDuration(60)
    #expect(viewport.span == 60)
  }
}

struct TimelineRulerTests {
  @Test func picksReadableTickSteps() {
    #expect(TimelineRuler.tickInterval(span: 1800, width: 900, minSpacing: 70) == 300)
    #expect(TimelineRuler.tickInterval(span: 5, width: 900, minSpacing: 70) == 0.5)
    #expect(TimelineRuler.tickInterval(span: 60, width: 900, minSpacing: 70) == 5)
  }

  @Test func ticksCoverVisibleRange() {
    let ticks = TimelineRuler.ticks(start: 9, end: 21, interval: 5)
    #expect(ticks == [10, 15, 20])
  }
}
