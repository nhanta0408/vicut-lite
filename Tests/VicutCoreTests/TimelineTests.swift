import Testing
@testable import VicutCore

struct TimelineTests {
  @Test func noMarksIsSingleKeep() throws {
    let segs = try Timeline.normalize(marks: [], duration: 10)
    #expect(segs == [Segment(start: 0, end: 10, action: .keep)])
    #expect(Timeline.isUnedited(segs, duration: 10))
  }

  @Test func cutAndSpeedProduceKeptSegments() throws {
    let marks = [
      Segment(start: 10, end: 30, action: .cut),
      Segment(start: 30, end: 70, action: .speed(4))
    ]
    let segs = try Timeline.normalize(marks: marks, duration: 90)
    #expect(segs == [
      Segment(start: 0, end: 10, action: .keep),
      Segment(start: 30, end: 70, action: .speed(4)),
      Segment(start: 70, end: 90, action: .keep)
    ])
    #expect(Timeline.outputDuration(segs) == 40)
  }

  @Test func laterMarksOverrideEarlierOnes() throws {
    let marks = [
      Segment(start: 0, end: 10, action: .speed(2)),
      Segment(start: 4, end: 6, action: .keep)
    ]
    let segs = try Timeline.normalize(marks: marks, duration: 10)
    #expect(segs == [
      Segment(start: 0, end: 4, action: .speed(2)),
      Segment(start: 4, end: 6, action: .keep),
      Segment(start: 6, end: 10, action: .speed(2))
    ])
  }

  @Test func mergesAdjacentSameActionAndClampsToDuration() throws {
    let marks = [
      Segment(start: -5, end: 3, action: .speed(4)),
      Segment(start: 3, end: 50, action: .speed(4)),
      Segment(start: 8, end: 8, action: .cut)
    ]
    let segs = try Timeline.normalize(marks: marks, duration: 10)
    #expect(segs == [Segment(start: 0, end: 10, action: .speed(4))])
    #expect(Timeline.outputDuration(segs) == 2.5)
  }

  @Test func reversedRangeIsAccepted() throws {
    let segs = try Timeline.normalize(marks: [Segment(start: 8, end: 2, action: .cut)], duration: 10)
    #expect(segs == [
      Segment(start: 0, end: 2, action: .keep),
      Segment(start: 8, end: 10, action: .keep)
    ])
  }

  @Test func everythingCutThrows() {
    #expect(throws: TimelineError.emptyOutput) {
      try Timeline.normalize(marks: [Segment(start: 0, end: 10, action: .cut)], duration: 10)
    }
  }
}

struct TimelineResolveTests {
  @Test func resolveKeepsCutSegmentsForDisplay() {
    let segs = Timeline.resolve(marks: [Segment(start: 0, end: 10, action: .cut)], duration: 20)
    #expect(segs == [
      Segment(start: 0, end: 10, action: .cut),
      Segment(start: 10, end: 20, action: .keep)
    ])
  }
}
