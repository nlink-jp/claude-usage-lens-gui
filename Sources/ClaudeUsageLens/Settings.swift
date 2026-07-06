import Foundation

/// UserDefaults keys for the weekly-budget settings, plus their defaults.
enum SettingsKey {
    static let weeklyEnabled = "weeklyEnabled"
    static let limitBasis = "limitBasis"     // LimitBasis rawValue
    static let limitCost = "limitCostUSD"    // Double, dollars
    static let limitTokens = "limitTokens"   // Double, in+out token count
    static let resetWeekday = "resetWeekday" // Calendar weekday 1=Sun … 7=Sat
    static let resetHour = "resetHour"       // 0…23
    static let resetMinute = "resetMinute"   // 0…59
    static let warnPercent = "warnPercent"
    static let criticalPercent = "criticalPercent"
    static let notificationsEnabled = "weeklyNotificationsEnabled"

    static func registerDefaults(_ d: UserDefaults = .standard) {
        d.register(defaults: [
            weeklyEnabled: false,
            limitBasis: LimitBasis.cost.rawValue,
            limitCost: 200.0,
            limitTokens: 50_000_000.0,
            resetWeekday: 2, // Monday
            resetHour: 0,
            resetMinute: 0,
            warnPercent: 80.0,
            criticalPercent: 95.0,
            notificationsEnabled: true,
        ])
    }
}

/// A snapshot of the weekly-budget settings, read from UserDefaults. UsageModel
/// isn't a View, so it can't use @AppStorage — it reads through this. The
/// SettingsView binds the same keys via @AppStorage.
struct WeeklySettings {
    let enabled: Bool
    let basis: LimitBasis
    let limit: Double
    let weekday: Int
    let hour: Int
    let minute: Int
    let warnPercent: Double
    let criticalPercent: Double
    let notificationsEnabled: Bool

    static func current(_ d: UserDefaults = .standard) -> WeeklySettings {
        let basis = LimitBasis(rawValue: d.string(forKey: SettingsKey.limitBasis) ?? "cost") ?? .cost
        return WeeklySettings(
            enabled: d.bool(forKey: SettingsKey.weeklyEnabled),
            basis: basis,
            limit: basis == .cost ? d.double(forKey: SettingsKey.limitCost)
                                   : d.double(forKey: SettingsKey.limitTokens),
            weekday: d.integer(forKey: SettingsKey.resetWeekday),
            hour: d.integer(forKey: SettingsKey.resetHour),
            minute: d.integer(forKey: SettingsKey.resetMinute),
            warnPercent: d.double(forKey: SettingsKey.warnPercent),
            criticalPercent: d.double(forKey: SettingsKey.criticalPercent),
            notificationsEnabled: d.bool(forKey: SettingsKey.notificationsEnabled)
        )
    }
}
