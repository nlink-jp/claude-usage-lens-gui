import XCTest
@testable import ClaudeUsageLens

final class WeeklyLimitTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func testStateThresholds() {
        XCTAssertEqual(WeeklyLimit.state(percent: 50, warnPercent: 80, criticalPercent: 95).rank, LimitState.normal.rank)
        XCTAssertEqual(WeeklyLimit.state(percent: 80, warnPercent: 80, criticalPercent: 95).rank, LimitState.warning.rank)
        XCTAssertEqual(WeeklyLimit.state(percent: 94, warnPercent: 80, criticalPercent: 95).rank, LimitState.warning.rank)
        XCTAssertEqual(WeeklyLimit.state(percent: 95, warnPercent: 80, criticalPercent: 95).rank, LimitState.critical.rank)
        XCTAssertEqual(WeeklyLimit.state(percent: 130, warnPercent: 80, criticalPercent: 95).rank, LimitState.critical.rank)
    }

    func testLastResetLandsOnWeekdayAtTime() {
        let cal = utcCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 12))!
        let r = WeeklyLimit.lastReset(weekday: 2, hour: 9, minute: 30, now: now, calendar: cal)
        XCTAssertEqual(cal.component(.weekday, from: r), 2)      // target weekday
        XCTAssertEqual(cal.component(.hour, from: r), 9)
        XCTAssertEqual(cal.component(.minute, from: r), 30)
        XCTAssertLessThanOrEqual(r, now)                         // in the past
        XCTAssertGreaterThan(r, cal.date(byAdding: .day, value: -7, to: now)!) // within a week
    }

    func testLastResetTodayButTimeNotReached() {
        let cal = utcCalendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 12))!
        let today = cal.component(.weekday, from: now)
        // Reset today at 13:00, but it's 12:00 now → last reset is the prior week.
        let r = WeeklyLimit.lastReset(weekday: today, hour: 13, minute: 0, now: now, calendar: cal)
        XCTAssertEqual(cal.component(.weekday, from: r), today)
        XCTAssertLessThan(r, cal.startOfDay(for: now))          // not today
        XCTAssertGreaterThan(r, cal.date(byAdding: .day, value: -8, to: now)!)
    }

    func testNextResetIsSevenDaysLater() {
        let cal = utcCalendar()
        let reset = cal.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 9))!
        let next = WeeklyLimit.nextReset(from: reset, calendar: cal)
        XCTAssertEqual(next, cal.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 9))!)
    }

    func testWeeklyStatusMath() {
        let w = WeeklyStatus(basis: .cost, used: 150, limit: 200, state: .warning,
                             resetStart: Date(), nextReset: Date())
        XCTAssertEqual(w.percent, 75, accuracy: 0.001)
        XCTAssertEqual(w.remaining, 50, accuracy: 0.001)
        // Over budget → remaining clamps at 0.
        let over = WeeklyStatus(basis: .cost, used: 250, limit: 200, state: .critical,
                                resetStart: Date(), nextReset: Date())
        XCTAssertEqual(over.remaining, 0, accuracy: 0.001)
    }
}
