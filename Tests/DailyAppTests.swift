import Testing
@testable import DailyApp

struct TallyTests {
    @Test func startsAtZero() {
        #expect(Tally().count == 0)
    }

    @Test func incrementAddsOne() {
        var tally = Tally(count: 41)
        tally.increment()
        #expect(tally.count == 42)
    }

    @Test func incrementStopsAtMaximum() {
        var tally = Tally(count: Tally.maximum)
        tally.increment()
        #expect(tally.count == Tally.maximum)
    }

    @Test(arguments: [(-5, 0), (0, 0), (10, 10), (Tally.maximum + 1, Tally.maximum)])
    func initClampsOutOfRangeValues(input: Int, expected: Int) {
        #expect(Tally(count: input).count == expected)
    }

    @Test func resetReturnsToZero() {
        var tally = Tally(count: 7)
        tally.reset()
        #expect(tally.count == 0)
    }
}
