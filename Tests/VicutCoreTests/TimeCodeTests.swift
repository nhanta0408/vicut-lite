import Testing
@testable import VicutCore

struct TimeCodeTests {
  @Test func parsesSecondsMinutesAndHours() {
    #expect(TimeCode.parse("12") == 12)
    #expect(TimeCode.parse("12.5") == 12.5)
    #expect(TimeCode.parse(".5") == 0.5)
    #expect(TimeCode.parse("0:31.0") == 31)
    #expect(TimeCode.parse(" 1:30 ") == 90)
    #expect(TimeCode.parse("75") == 75)
    #expect(TimeCode.parse("1:02:03.5") == 3723.5)
    #expect(TimeCode.parse("90:00") == 5400)
  }

  @Test func rejectsMalformedText() {
    for text in ["", ".", "abc", "1:", ":30", "1:60", "1:75:00", "1:2:3:4", "-5", "1.2.3", "1:-2", "1e3", "+1:00"] {
      #expect(TimeCode.parse(text) == nil, "\(text)")
    }
  }

  @Test func releasingThenRepaintingMovesASpan() {
    let cut = Segment(start: 31, end: 34.3, action: .cut)
    let marks = [cut, Segment(start: 40, end: 45, action: .speed(2))]
    let moved = Timeline.releasing(cut, marks: marks) + [Segment(start: 32, end: 36, action: .cut)]
    let spans = Timeline.resolve(marks: moved, duration: 90)
    #expect(spans.contains(Segment(start: 32, end: 36, action: .cut)))
    #expect(spans.first == Segment(start: 0, end: 32, action: .keep))
  }

  @Test func releasingANormalSpanChangesNothing() {
    let marks = [Segment(start: 31, end: 34.3, action: .cut)]
    #expect(Timeline.releasing(Segment(start: 0, end: 31, action: .keep), marks: marks) == marks)
  }
}
