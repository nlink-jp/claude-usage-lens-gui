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
                             resetStart: Date(), nextReset: Date(),
                             calibrated: false, calibrationAgeDays: nil)
        XCTAssertEqual(w.percent, 75, accuracy: 0.001)
        XCTAssertEqual(w.remaining, 50, accuracy: 0.001)
        // Over budget → remaining clamps at 0.
        let over = WeeklyStatus(basis: .cost, used: 250, limit: 200, state: .critical,
                                resetStart: Date(), nextReset: Date(),
                                calibrated: false, calibrationAgeDays: nil)
        XCTAssertEqual(over.remaining, 0, accuracy: 0.001)
    }

    // Calibrated vs. assumed is part of identity: a status flipping between the
    // two must publish (the popover badge and Settings row depend on it).
    func testWeeklyStatusEqualityTracksCalibrated() {
        let t = Date(timeIntervalSince1970: 1_770_000_000)
        let a = WeeklyStatus(basis: .cost, used: 10, limit: 100, state: .normal,
                             resetStart: t, nextReset: t,
                             calibrated: false, calibrationAgeDays: nil)
        let b = WeeklyStatus(basis: .cost, used: 10, limit: 100, state: .normal,
                             resetStart: t, nextReset: t,
                             calibrated: true, calibrationAgeDays: 0.5)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - Percent display

final class WeeklyPercentDisplayTests: XCTestCase {
    private func status(used: Double, limit: Double) -> WeeklyStatus {
        WeeklyStatus(basis: .cost, used: used, limit: limit, state: .normal,
                     resetStart: Date(), nextReset: Date(),
                     calibrated: false, calibrationAgeDays: nil)
    }

    // The used/left percents are shown side by side, so they must sum to 100 —
    // rounding each independently would print "42% used · 57% left".
    func testUsedAndRemainingPercentsSumTo100() {
        for used in stride(from: 0.0, through: 200.0, by: 0.37) {
            let w = status(used: used, limit: 200)
            XCTAssertEqual(w.usedPercentDisplay + w.remainingPercentDisplay, 100,
                           "used=\(used) split doesn't sum to 100")
        }
    }

    func testOverBudgetPinsRemainingAtZero() {
        let w = status(used: 324, limit: 200)
        XCTAssertEqual(w.usedPercentDisplay, 162)   // keeps counting past 100
        XCTAssertEqual(w.remainingPercentDisplay, 0)
        XCTAssertEqual(w.remaining, 0, accuracy: 0.001)
    }

    func testMenuBarWeeklyLabelCarriesPercent() {
        let m = UsageModel()
        m.weeklyStatus = status(used: 84, limit: 200)
        XCTAssertEqual(m.weeklyRemainingLabel, "$116 · 58%")

        m.weeklyStatus = WeeklyStatus(basis: .tokens, used: 20_000_000, limit: 50_000_000,
                                      state: .normal, resetStart: Date(), nextReset: Date(),
                                      calibrated: false, calibrationAgeDays: nil)
        XCTAssertEqual(m.weeklyRemainingLabel, "30.0M · 60%")
    }
}

// MARK: - Burn-rate forecast

final class WeeklyForecastTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_770_000_000)
    private var end: Date { start.addingTimeInterval(7 * 86_400) }
    private func at(days: Double) -> Date { start.addingTimeInterval(days * 86_400) }

    /// Half the week gone, half the budget spent → lands exactly on the limit,
    /// at the reset instant.
    func testOnPaceForExactlyTheLimit() {
        let f = WeeklyLimit.forecast(used: 100, limit: 200, windowStart: start, windowEnd: end,
                                     now: at(days: 3.5), warnPercent: 80)!
        XCTAssertEqual(f.elapsedFraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(f.projectedUsed, 200, accuracy: 0.0001)
        XCTAssertEqual(f.projectedPercent, 100, accuracy: 0.0001)
        XCTAssertTrue(f.willExceed)
        XCTAssertEqual(f.state.rank, LimitState.critical.rank)  // ≥100% is always critical
        XCTAssertEqual(f.exhaustionDate!.timeIntervalSince1970, end.timeIntervalSince1970, accuracy: 1)
    }

    func testOverPaceProjectsExhaustionBeforeReset() {
        let f = WeeklyLimit.forecast(used: 150, limit: 200, windowStart: start, windowEnd: end,
                                     now: at(days: 3.5), warnPercent: 80)!
        XCTAssertEqual(f.projectedUsed, 300, accuracy: 0.0001)
        XCTAssertEqual(f.projectedPercent, 150, accuracy: 0.0001)
        XCTAssertTrue(f.willExceed)
        // $50 left at $150 / 3.5d → 1.1667 more days.
        XCTAssertEqual(f.exhaustionDate!.timeIntervalSince1970,
                       at(days: 3.5 + 50.0 / (150.0 / 3.5)).timeIntervalSince1970, accuracy: 1)
    }

    func testUnderPaceStaysWithinBudget() {
        let f = WeeklyLimit.forecast(used: 50, limit: 200, windowStart: start, windowEnd: end,
                                     now: at(days: 3.5), warnPercent: 80)!
        XCTAssertEqual(f.projectedPercent, 50, accuracy: 0.0001)
        XCTAssertFalse(f.willExceed)
        XCTAssertEqual(f.state.rank, LimitState.normal.rank)
        XCTAssertNil(f.exhaustionDate)   // the limit isn't reached before the reset
    }

    /// Between the warning threshold and the limit: flagged, but not critical.
    func testProjectionAboveWarnThresholdIsWarning() {
        let f = WeeklyLimit.forecast(used: 90, limit: 200, windowStart: start, windowEnd: end,
                                     now: at(days: 3.5), warnPercent: 80)!
        XCTAssertEqual(f.projectedPercent, 90, accuracy: 0.0001)
        XCTAssertEqual(f.state.rank, LimitState.warning.rank)
        XCTAssertFalse(f.willExceed)
    }

    /// Already over: no exhaustion instant to name (it's in the past).
    func testAlreadyOverBudget() {
        let f = WeeklyLimit.forecast(used: 250, limit: 200, windowStart: start, windowEnd: end,
                                     now: at(days: 3.5), warnPercent: 80)!
        XCTAssertTrue(f.willExceed)
        XCTAssertNil(f.exhaustionDate)
    }

    /// One burst in the first hour would project an absurd week — flagged, not shown as fact.
    func testEarlyWindowIsUnreliable() {
        let early = WeeklyLimit.forecast(used: 20, limit: 200, windowStart: start, windowEnd: end,
                                         now: at(days: 1.0 / 24), warnPercent: 80)!
        XCTAssertFalse(early.reliable)
        // Just past the 5%-of-a-week mark (~8.4h) the projection is taken seriously.
        let later = WeeklyLimit.forecast(used: 20, limit: 200, windowStart: start, windowEnd: end,
                                         now: at(days: 0.5), warnPercent: 80)!
        XCTAssertTrue(later.reliable)
    }

    func testNoProjectionFromDegenerateInputs() {
        // No limit to project against.
        XCTAssertNil(WeeklyLimit.forecast(used: 10, limit: 0, windowStart: start, windowEnd: end,
                                          now: at(days: 1), warnPercent: 80))
        // Window with no duration.
        XCTAssertNil(WeeklyLimit.forecast(used: 10, limit: 200, windowStart: start, windowEnd: start,
                                          now: at(days: 1), warnPercent: 80))
        // At / before the window start: nothing has elapsed to extrapolate from.
        XCTAssertNil(WeeklyLimit.forecast(used: 0, limit: 200, windowStart: start, windowEnd: end,
                                          now: start, warnPercent: 80))
        // Stale window (the next refresh moves it forward).
        XCTAssertNil(WeeklyLimit.forecast(used: 10, limit: 200, windowStart: start, windowEnd: end,
                                          now: at(days: 8), warnPercent: 80))
    }

    func testZeroUsageProjectsZero() {
        let f = WeeklyLimit.forecast(used: 0, limit: 200, windowStart: start, windowEnd: end,
                                     now: at(days: 3.5), warnPercent: 80)!
        XCTAssertEqual(f.projectedUsed, 0, accuracy: 0.0001)
        XCTAssertNil(f.exhaustionDate)
        XCTAssertFalse(f.willExceed)
    }

    // MARK: label

    private func status(used: Double, limit: Double, now: Date) -> WeeklyStatus {
        let f = WeeklyLimit.forecast(used: used, limit: limit, windowStart: start, windowEnd: end,
                                     now: now, warnPercent: 80)
        return WeeklyStatus(basis: .cost, used: used, limit: limit, state: .normal,
                            resetStart: start, nextReset: end,
                            calibrated: false, calibrationAgeDays: nil, forecast: f)
    }

    func testForecastLabels() {
        let over = status(used: 150, limit: 200, now: at(days: 3.5))
        XCTAssertEqual(UsageModel.forecastLabel(over),
                       "On pace for $300.00 (150%) — budget gone \(UsageModel.resetLabel(over.forecast!.exhaustionDate!))")

        let fine = status(used: 50, limit: 200, now: at(days: 3.5))
        XCTAssertEqual(UsageModel.forecastLabel(fine), "On pace for $100.00 (50%) by reset")

        let spent = status(used: 250, limit: 200, now: at(days: 3.5))
        XCTAssertEqual(UsageModel.forecastLabel(spent), "Over budget — on pace for $500.00 (250%)")

        // The early window names its own state instead of going quiet.
        let early = status(used: 20, limit: 200, now: at(days: 1.0 / 24))
        XCTAssertEqual(UsageModel.forecastLabel(early), "Too early this week to project a pace")

        // No forecast at all → the pace line is simply absent.
        let none = WeeklyStatus(basis: .cost, used: 10, limit: 200, state: .normal,
                                resetStart: start, nextReset: end,
                                calibrated: false, calibrationAgeDays: nil)
        XCTAssertNil(UsageModel.forecastLabel(none))
    }

    func testForecastIcons() {
        XCTAssertEqual(UsageModel.forecastIcon(status(used: 150, limit: 200, now: at(days: 3.5))),
                       "exclamationmark.triangle.fill")
        XCTAssertEqual(UsageModel.forecastIcon(status(used: 90, limit: 200, now: at(days: 3.5))),
                       "exclamationmark.circle")
        XCTAssertEqual(UsageModel.forecastIcon(status(used: 50, limit: 200, now: at(days: 3.5))),
                       "checkmark.circle")
        XCTAssertEqual(UsageModel.forecastIcon(status(used: 20, limit: 200, now: at(days: 1.0 / 24))),
                       "clock")
    }
}
