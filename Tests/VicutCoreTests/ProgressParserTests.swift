import Testing
@testable import VicutCore

struct ProgressParserTests {
  @Test func reportsFractionFromOutTime() {
    var parser = ProgressParser(totalDuration: 10)
    #expect(parser.consume(line: "frame=10") == nil)
    #expect(parser.consume(line: "out_time_us=2500000") == 0.25)
    #expect(parser.consume(line: "out_time_us=N/A") == nil)
  }

  @Test func clampsAndFinishesOnEnd() {
    var parser = ProgressParser(totalDuration: 1)
    #expect(parser.consume(line: "out_time_us=5000000") == 1)
    #expect(parser.consume(line: "progress=end") == 1)
  }

  @Test func zeroDurationNeverDividesByZero() {
    var parser = ProgressParser(totalDuration: 0)
    #expect(parser.consume(line: "out_time_us=1000") == 0)
  }
}
