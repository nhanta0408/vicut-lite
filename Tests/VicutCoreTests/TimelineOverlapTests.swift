import Testing
@testable import VicutCore

struct TimelineOverlapTests {
  private let marks = [
    Segment(start: 31, end: 34.3, action: .cut),
    Segment(start: 40, end: 45, action: .speed(2))
  ]

  @Test func spanFullyInsideIsCovered() {
    let impact = Timeline.overlap(of: 30...36, action: .speed(2), marks: marks, duration: 90)
    #expect(impact.covered == [Segment(start: 31, end: 34.3, action: .cut)])
    #expect(impact.trimmed.isEmpty)
  }

  @Test func partialOverlapIsTrimmedNotCovered() {
    let impact = Timeline.overlap(of: 33...42, action: .cut, marks: marks, duration: 90)
    #expect(impact.covered.isEmpty)
    #expect(impact.trimmed == [Segment(start: 40, end: 45, action: .speed(2))])
  }

  @Test func sameActionMergesInsteadOfReplacing() {
    let impact = Timeline.overlap(of: 30...36, action: .cut, marks: marks, duration: 90)
    #expect(impact.covered.isEmpty)
    #expect(impact.trimmed.isEmpty)
  }

  @Test func normalPartsAreNeverReported() {
    let impact = Timeline.overlap(of: 0...20, action: .cut, marks: marks, duration: 90)
    #expect(impact.isEmpty)
  }

  @Test func spanContainingRangeIsTrimmed() {
    let impact = Timeline.overlap(of: 41...42, action: .cut, marks: marks, duration: 90)
    #expect(impact.covered.isEmpty)
    #expect(impact.trimmed == [Segment(start: 40, end: 45, action: .speed(2))])
  }

  @Test func spanAtPointFindsContainingSegment() {
    let span = Timeline.span(at: 32, marks: marks, duration: 90)
    #expect(span == Segment(start: 31, end: 34.3, action: .cut))
    #expect(Timeline.span(at: 90, marks: marks, duration: 90) == Segment(start: 45, end: 90, action: .keep))
  }
}
