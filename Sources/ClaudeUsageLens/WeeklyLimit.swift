import Foundation
import SwiftUI

/// What the weekly budget is measured in.
enum LimitBasis: String, CaseIterable, Identifiable {
    case cost, tokens
    var id: String { rawValue }
    var label: String { self == .cost ? "Cost ($)" : "Tokens (in+out)" }
}

/// Two-tier warning state for the weekly budget.
enum LimitState {
    case normal, warning, critical

    /// Menu-bar tint; nil = default (no override).
    var color: Color? {
        switch self {
        case .normal: return nil
        case .warning: return .orange
        case .critical: return .red
        }
    }

    /// Severity, for detecting upward transitions (to notify once per crossing).
    var rank: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}

/// A linear burn-rate projection over the current weekly window: where the week
/// lands if usage keeps flowing at the average rate observed so far.
struct WeeklyForecast: Equatable {
    /// How far through the window we are, 0…1.
    let elapsedFraction: Double
    /// Usage extrapolated to the window end at the observed average rate.
    let projectedUsed: Double
    /// `projectedUsed` as a percentage of the limit — may exceed 100.
    let projectedPercent: Double
    /// When the limit is reached at this rate, if that instant falls inside the
    /// window. nil = not before the reset, or already over the limit.
    let exhaustionDate: Date?
    /// False in the first sliver of the window, where a single session dominates
    /// the average and the extrapolation is noise. The UI says so rather than
    /// presenting a wild number as a forecast.
    let reliable: Bool
    /// Severity of the projection itself: critical at ≥100% of the limit,
    /// warning at ≥ the user's warning threshold.
    let state: LimitState

    var willExceed: Bool { projectedPercent >= 100 }
}

/// Immutable snapshot of the weekly budget vs. usage.
struct WeeklyStatus: Equatable {
    let basis: LimitBasis
    let used: Double
    let limit: Double
    let state: LimitState
    let resetStart: Date  // the reset instant the current window began at
    let nextReset: Date
    /// True when `limit` is the cap derived from an official /usage reading
    /// (CLI `limits`), false when it is the user's assumed budget.
    let calibrated: Bool
    /// Days since the calibration reading (calibrated only) — staleness hint.
    let calibrationAgeDays: Double?
    /// Where this week lands at the current pace; nil when no projection can be
    /// derived (degenerate window, or `now` outside it).
    let forecast: WeeklyForecast?

    init(basis: LimitBasis, used: Double, limit: Double, state: LimitState,
         resetStart: Date, nextReset: Date, calibrated: Bool,
         calibrationAgeDays: Double?, forecast: WeeklyForecast? = nil) {
        self.basis = basis
        self.used = used
        self.limit = limit
        self.state = state
        self.resetStart = resetStart
        self.nextReset = nextReset
        self.calibrated = calibrated
        self.calibrationAgeDays = calibrationAgeDays
        self.forecast = forecast
    }

    var percent: Double { limit > 0 ? used / limit * 100 : 0 }
    var remaining: Double { max(0, limit - used) }

    /// Whole percents for display, derived as a pair so "42% used · 58% left"
    /// always sums to 100 — rounding the two independently would show 42/57.
    /// Over budget, `usedPercentDisplay` keeps going past 100 and the remainder
    /// pins at 0, matching `remaining`.
    var usedPercentDisplay: Int { Int(percent.rounded()) }
    var remainingPercentDisplay: Int { max(0, 100 - usedPercentDisplay) }

    static func == (a: WeeklyStatus, b: WeeklyStatus) -> Bool {
        a.basis == b.basis && a.used == b.used && a.limit == b.limit
            && a.state.rank == b.state.rank && a.resetStart == b.resetStart
            && a.calibrated == b.calibrated
    }
}

/// Pure helpers for the weekly-reset window and threshold state.
enum WeeklyLimit {
    /// The most recent reset instant at or before `now`, for a weekly reset at
    /// (`weekday`, `hour`, `minute`). `weekday` is Calendar's 1=Sun … 7=Sat. The
    /// calendar carries the timezone.
    static func lastReset(weekday: Int, hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date {
        let cal = calendar
        let todayWeekday = cal.component(.weekday, from: now)
        let delta = (todayWeekday - weekday + 7) % 7 // days since the target weekday (0 = today)
        let day = cal.date(byAdding: .day, value: -delta, to: cal.startOfDay(for: now)) ?? now
        var candidate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        if candidate > now {
            // The reset weekday is today but its time hasn't passed → last week's.
            candidate = cal.date(byAdding: .day, value: -7, to: candidate) ?? candidate
        }
        return candidate
    }

    static func nextReset(from lastReset: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 7, to: lastReset) ?? lastReset.addingTimeInterval(7 * 86_400)
    }

    /// normal < warnPercent ≤ warning < criticalPercent ≤ critical.
    static func state(percent: Double, warnPercent: Double, criticalPercent: Double) -> LimitState {
        if percent >= criticalPercent { return .critical }
        if percent >= warnPercent { return .warning }
        return .normal
    }

    /// Project the window's end state from the pace so far: `used` spread over
    /// the elapsed slice of [`windowStart`, `windowEnd`], extrapolated linearly
    /// to the whole window. Returns nil when there is nothing to project from —
    /// no limit, a degenerate window, or `now` outside it (a stale window is
    /// corrected by the next refresh).
    ///
    /// `minimumElapsedFraction` guards the noisy head of the window: 5% of a
    /// week is ~8h, before which one session's burst would project an absurd
    /// total, so the result is flagged `reliable: false` instead.
    static func forecast(used: Double, limit: Double,
                         windowStart: Date, windowEnd: Date, now: Date,
                         warnPercent: Double,
                         minimumElapsedFraction: Double = 0.05) -> WeeklyForecast? {
        let total = windowEnd.timeIntervalSince(windowStart)
        let elapsed = now.timeIntervalSince(windowStart)
        guard limit > 0, total > 0, elapsed > 0, elapsed <= total else { return nil }

        let elapsedFraction = elapsed / total
        let projectedUsed = used / elapsedFraction
        let projectedPercent = projectedUsed / limit * 100

        // Time to the limit at the average rate, when it lands before the reset.
        var exhaustion: Date?
        let ratePerSecond = used / elapsed
        if used < limit, ratePerSecond > 0 {
            let hit = now.addingTimeInterval((limit - used) / ratePerSecond)
            if hit <= windowEnd { exhaustion = hit }
        }

        return WeeklyForecast(
            elapsedFraction: elapsedFraction,
            projectedUsed: projectedUsed,
            projectedPercent: projectedPercent,
            exhaustionDate: exhaustion,
            reliable: elapsedFraction >= minimumElapsedFraction,
            // Anything projecting to 100% of the limit is critical regardless of
            // where the user put their "critical" threshold for actual usage.
            state: state(percent: projectedPercent, warnPercent: warnPercent, criticalPercent: 100))
    }
}
