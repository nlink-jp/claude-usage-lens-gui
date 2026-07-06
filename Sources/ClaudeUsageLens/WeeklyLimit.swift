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

/// Immutable snapshot of the weekly budget vs. usage.
struct WeeklyStatus: Equatable {
    let basis: LimitBasis
    let used: Double
    let limit: Double
    let state: LimitState
    let resetStart: Date  // the reset instant the current window began at
    let nextReset: Date

    var percent: Double { limit > 0 ? used / limit * 100 : 0 }
    var remaining: Double { max(0, limit - used) }

    static func == (a: WeeklyStatus, b: WeeklyStatus) -> Bool {
        a.basis == b.basis && a.used == b.used && a.limit == b.limit
            && a.state.rank == b.state.rank && a.resetStart == b.resetStart
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
}
