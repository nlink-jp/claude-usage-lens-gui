import Foundation
import UserNotifications

/// UsageModel drives the UI: it periodically ingests and pulls today's summary
/// for the menu-bar label + popover, and loads the richer breakdowns for the
/// analysis window on demand. All CLI work runs off the main thread; @Published
/// mutations are hopped back to main.
final class UsageModel: ObservableObject {
    @Published var todaySummary: Summary?
    @Published var last30USD: Double?       // actual last-30-days total (matches the analysis panel)
    @Published var weeklyStatus: WeeklyStatus?  // weekly-budget monitor (nil = disabled/unavailable)
    @Published var lastError: String?       // short, user-facing summary
    @Published var lastErrorDetail: String? // raw CLI output, shown smaller
    @Published var lastUpdated: Date?
    @Published var unpriced: UnpricedUsage?  // $0-but-billable turns in the last 30 days (nil = none)
    @Published var repricePhase: RepricePhase = .idle  // the Reprice button's own state, per badge episode

    private var lastNotifiedRank = 0        // highest state we've already notified, this window

    // Analysis window state
    @Published var period: String = "7d"
    @Published var periodSummary: Summary?  // total/tokens for the selected period (same summary derivation as the popover)
    @Published var dailyRows: [Row] = []
    @Published var dailyByModelRows: [Row] = [] // group-by day,model — for the stacked view
    @Published var modelRows: [Row] = []
    @Published var projectRows: [Row] = []

    private var timer: Timer?
    private var activity: NSObjectProtocol?  // App Nap opt-out (retain for the app's lifetime)
    private let queue = DispatchQueue(label: "jp.nlink.claude-usage-lens-gui.cli", qos: .utility)

    /// Today's cost as "$12.34" (menu-bar / popover).
    var todayPrice: String {
        if let s = todaySummary { return String(format: "$%.2f", s.totalUSD) }
        if lastError != nil { return "—" }
        return "…"
    }

    /// Today's total token throughput (input + output + cache) as "277M".
    var todayTokens: String {
        guard let s = todaySummary else { return lastError != nil ? "—" : "…" }
        return PopoverView.compact(s.inputTokens + s.outputTokens + s.cacheTokens)
    }

    /// The weekly-remaining menu-bar label — the amount left plus the same figure
    /// as a share of the budget ("$116 · 58%"), since a bare amount says nothing
    /// about how much of the week it covers. Falls back to today's cost when the
    /// weekly monitor is off.
    var weeklyRemainingLabel: String {
        guard let w = weeklyStatus else { return todayPrice }
        let amount: String
        switch w.basis {
        case .cost: amount = String(format: "$%.0f", w.remaining)   // menu bar: no cents
        case .tokens: amount = PopoverView.compact(Int(w.remaining))
        }
        return "\(amount) · \(w.remainingPercentDisplay)%"
    }

    // MARK: - Weekly budget

    /// Raw usage over the current weekly window, basis-independent. Cached so the
    /// status can be rebuilt instantly when the limit/basis/thresholds change,
    /// without another CLI call. When the CLI holds a usable calibration
    /// (ADR-0001), the derived caps ride along and take precedence over the
    /// user's assumed budget.
    private struct WeeklyUsage {
        let cost: Double
        let tokens: Double
        let reset: Date
        let nextReset: Date
        let capCost: Double?          // calibrated cap (nil = not calibrated)
        let capTokens: Double?
        let calibrationAgeDays: Double?
    }
    private var weeklyUsage: WeeklyUsage?

    /// Query usage for the current weekly window. Best-effort (nil when
    /// disabled/CLI error). Prefers the CLI's calibrated view — its window
    /// cadence comes from the official reset instant — and falls back to the
    /// settings-defined window with the assumed budget. Runs on the background
    /// queue.
    private func fetchWeeklyUsage() -> WeeklyUsage? {
        let s = WeeklySettings.current()
        guard s.enabled else { return nil }
        if let p = try? CLIRunner.limits(), p.calibrated, let st = p.status {
            return WeeklyUsage(
                cost: st.consumed.costUSD, tokens: Double(st.consumed.tokens),
                reset: st.windowStart, nextReset: st.windowEnd,
                capCost: st.caps.costUSD, capTokens: Double(st.caps.tokens),
                calibrationAgeDays: st.calibration.ageDays)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let reset = WeeklyLimit.lastReset(weekday: s.weekday, hour: s.hour, minute: s.minute, now: Date(), calendar: cal)
        guard let summary = try? CLIRunner.summary(since: Self.datetimeString(reset)) else { return nil }
        return WeeklyUsage(cost: summary.totalUSD, tokens: Double(summary.inputTokens + summary.outputTokens),
                           reset: reset, nextReset: WeeklyLimit.nextReset(from: reset, calendar: cal),
                           capCost: nil, capTokens: nil, calibrationAgeDays: nil)
    }

    /// Build the status from the cached usage + current settings — no CLI. A
    /// calibrated cap wins over the assumed budget on whichever basis is shown.
    private func buildWeeklyStatus() -> WeeklyStatus? {
        let s = WeeklySettings.current()
        guard s.enabled, let u = weeklyUsage else { return nil }
        let calibratedLimit = s.basis == .cost ? u.capCost : u.capTokens
        let limit = calibratedLimit ?? s.limit
        guard limit > 0 else { return nil }
        let used = s.basis == .cost ? u.cost : u.tokens
        let percent = used / limit * 100
        let state = WeeklyLimit.state(percent: percent, warnPercent: s.warnPercent, criticalPercent: s.criticalPercent)
        // Where this week lands at the pace so far. Derived here (not in the
        // view) so the views stay dumb and the maths stays testable; it is as
        // fresh as `used`, i.e. rebuilt on every refresh and settings change.
        let forecast = WeeklyLimit.forecast(
            used: used, limit: limit,
            windowStart: u.reset, windowEnd: u.nextReset, now: Date(),
            warnPercent: s.warnPercent)
        return WeeklyStatus(basis: s.basis, used: used, limit: limit, state: state,
                            resetStart: u.reset, nextReset: u.nextReset,
                            calibrated: calibratedLimit != nil,
                            calibrationAgeDays: u.calibrationAgeDays,
                            forecast: forecast)
    }

    // MARK: - Calibration (ADR-0001)

    /// Feedback line for the Settings calibration section (success or failure).
    @Published var calibrationMessage: String?

    /// Record an official /usage reading via the CLI, then refresh the weekly
    /// status so the derived cap applies immediately.
    func calibrate(utilizationPct: Double, resetsAt: Date) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let res = try CLIRunner.calibrateAdd(utilizationPct: utilizationPct, resetsAt: resetsAt)
                let usage = self.fetchWeeklyUsage()
                DispatchQueue.main.async {
                    self.weeklyUsage = usage
                    self.applyWeekly(self.buildWeeklyStatus(), notify: false)
                    self.calibrationMessage = String(
                        format: "Calibrated — weekly cap ≈ $%.2f / %@ tokens",
                        res.caps.costUSD, PopoverView.compact(res.caps.tokens))
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                DispatchQueue.main.async { self.calibrationMessage = msg }
            }
        }
    }

    /// Set the status, notifying once when severity rises — only `notify: true`
    /// (the periodic refresh), never while the user tunes settings. Main thread.
    private func applyWeekly(_ w: WeeklyStatus?, notify: Bool) {
        weeklyStatus = w
        let rank = w?.state.rank ?? 0
        if notify, WeeklySettings.current().notificationsEnabled,
           let w, rank > lastNotifiedRank {
            notifyWeekly(w)
        }
        lastNotifiedRank = rank
    }

    /// Rebuild the status from cached usage instantly — for limit/basis/threshold
    /// changes in Settings. No CLI call, no notification.
    func applyWeeklySettings() {
        applyWeekly(buildWeeklyStatus(), notify: false)
    }

    /// Re-query weekly usage for a new window (reset day/time or enable changed),
    /// then rebuild. Background CLI call; no notification (user-initiated).
    func refreshWeekly() {
        queue.async { [weak self] in
            guard let self else { return }
            let usage = self.fetchWeeklyUsage()
            DispatchQueue.main.async {
                self.weeklyUsage = usage
                self.applyWeekly(self.buildWeeklyStatus(), notify: false)
            }
        }
    }

    /// Ask for notification permission (once). Call when the monitor is enabled.
    func requestNotificationAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyWeekly(_ w: WeeklyStatus) {
        let content = UNMutableNotificationContent()
        content.title = w.state == .critical ? "Weekly budget critical" : "Weekly budget warning"
        content.body = "Used \(Self.amount(w.used, w.basis)) of \(Self.amount(w.limit, w.basis)) "
            + "(\(Int(w.percent))%). Resets \(Self.resetLabel(w.nextReset))."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "weekly-\(w.state.rank)-\(Int(w.resetStart.timeIntervalSince1970))",
            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    /// Format an amount per basis: "$123.45" or a compact token count.
    static func amount(_ v: Double, _ basis: LimitBasis) -> String {
        basis == .cost ? String(format: "$%.2f", v) : PopoverView.compact(Int(v))
    }

    /// One-line answer to "am I going to blow through the budget?", from the
    /// pace so far. nil when there is no projection to show; the early-window
    /// case says so out loud rather than going quiet.
    static func forecastLabel(_ w: WeeklyStatus) -> String? {
        guard let f = w.forecast else { return nil }
        guard f.reliable else { return "Too early this week to project a pace" }
        let projected = "\(amount(f.projectedUsed, w.basis)) (\(Int(f.projectedPercent.rounded()))%)"
        if w.used >= w.limit { return "Over budget — on pace for \(projected)" }
        if let hit = f.exhaustionDate {
            return "On pace for \(projected) — budget gone \(resetLabel(hit))"
        }
        return "On pace for \(projected) by reset"
    }

    /// SF Symbol for the pace line, matching `forecastLabel`.
    static func forecastIcon(_ w: WeeklyStatus) -> String {
        guard let f = w.forecast, f.reliable else { return "clock" }
        switch f.state {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle"
        case .normal: return "checkmark.circle"
        }
    }

    /// A local `yyyy-MM-dd'T'HH:mm` string the CLI parses as an exact instant.
    static func datetimeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.string(from: d)
    }

    /// A short "Mon 00:00" label for a reset time.
    static func resetLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE HH:mm"
        return f.string(from: d)
    }

    /// Turn a "Nd" period into a calendar start date (today − (N−1) days) as
    /// YYYY-MM-DD in `tz`, so a dense daily series spans exactly N calendar days
    /// aligned to the CLI's day buckets. The app uses the local timezone (and
    /// passes `--tz local` to the CLI) so "today" and day boundaries match the
    /// user's local day. Non-"Nd" periods pass through unchanged. `from`/`tz` are
    /// injectable for testing.
    static func calendarSince(_ period: String, from now: Date = Date(), tz: TimeZone = .current) -> String {
        guard period.hasSuffix("d"), let n = Int(period.dropLast()), n > 0 else { return period }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let start = cal.date(byAdding: .day, value: -(n - 1), to: cal.startOfDay(for: now)) ?? now
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }

    func start() {
        SettingsKey.registerDefaults()
        // Opt out of App Nap so the 60s refresh timer keeps firing while the app
        // sits in the menu bar (otherwise the menu-bar color / weekly value freeze
        // when macOS naps this windowless background app). System sleep is allowed.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "usage monitoring")
        let s = WeeklySettings.current()
        if s.enabled && s.notificationsEnabled { requestNotificationAuth() }
        refreshToday()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshToday()
        }
    }

    /// Ingest (keep the store fresh), then pull today's summary.
    func refreshToday() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try CLIRunner.ingest()
                let s = try CLIRunner.summary(since: "today")
                // Actual last-30-days total, on the same calendar window the
                // analysis panel uses, so the two reconcile.
                let last30 = try CLIRunner.summary(since: Self.calendarSince("30d"))
                let weeklyUsage = self.fetchWeeklyUsage() // best-effort; nil if off/error
                DispatchQueue.main.async {
                    self.todaySummary = s
                    self.last30USD = last30.totalUSD
                    self.unpriced = Self.unpricedUsage(last30)
                    // A cleared badge ends the episode: the next one starts
                    // with a fresh Reprice, whatever happened last time.
                    if self.unpriced == nil { self.repricePhase = .idle }
                    self.weeklyUsage = weeklyUsage
                    self.applyWeekly(self.buildWeeklyStatus(), notify: true)
                    self.lastError = nil
                    self.lastErrorDetail = nil
                    self.lastUpdated = Date()
                }
            } catch {
                self.setError(error)
            }
        }
    }

    // MARK: - Unpriced usage

    /// Apply the bundled CLI's current rates to the stored history (`reprice`),
    /// then refresh. This is the exit for the unpriced badge: after an app
    /// update the store still holds the $0 rows the previous build wrote, and
    /// one reprice corrects them in place. What is still unpriced afterwards is
    /// a model this build does not know either. Every phase of the attempt —
    /// running, failed, done-but-still-unpriced — is shown in the badge itself,
    /// on the control the user pressed; the button is never left dead.
    func reprice() {
        DispatchQueue.main.async { self.repricePhase = .running }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try CLIRunner.reprice()
                DispatchQueue.main.async { self.repricePhase = .done }
                self.refreshToday()
            } catch {
                let summary = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                DispatchQueue.main.async { self.repricePhase = .failed(summary) }
            }
        }
    }

    /// The badge state from a summary: nil when nothing is unpriced (or the CLI
    /// predates the field), otherwise the count and its per-model split.
    static func unpricedUsage(_ s: Summary) -> UnpricedUsage? {
        guard let n = s.unpricedRecords, n > 0 else { return nil }
        return UnpricedUsage(records: n, models: s.unpricedModels ?? [:])
    }

    /// The badge's headline: how many turns, on what, are counted at $0.
    static func unpricedLabel(_ u: UnpricedUsage) -> String {
        let turns = u.records == 1 ? "1 turn" : "\(u.records) turns"
        switch u.models.count {
        case 0: return "\(turns) counted at $0"
        case 1: return "\(turns) on \(u.models.keys.first!) counted at $0"
        default: return "\(turns) on \(u.models.count) models counted at $0"
        }
    }

    /// The badge's second line: the consequence and the way out, per phase of
    /// the Reprice attempt. Idle: the way out is the button. Running: say so
    /// (a silent second wait reads as a dead button). Failed: the reason, on
    /// the control that failed. Done with the badge still up: the rates this
    /// build ships do not know the model — update, or price it in the CLI's
    /// config and reprice again.
    static func unpricedHint(phase: RepricePhase) -> String {
        switch phase {
        case .idle:
            return "Missing from every figure shown (last 30 days). Reprice applies the current rates to stored history."
        case .running:
            return "Repricing stored history…"
        case .done:
            return "Still unpriced after repricing: this build's rates don't know the model. Update the app, or price it in the CLI config and reprice again."
        case .failed(let reason):
            return "Reprice failed: \(reason)"
        }
    }

    /// The menu-bar text with a warning mark appended while unpriced usage
    /// exists, so an understated number is never shown as if it were complete.
    static func menuLabel(_ base: String, unpriced: Bool) -> String {
        unpriced ? base + " ⚠︎" : base
    }

    /// Set the user-facing error summary plus the raw CLI detail (issue #2), on
    /// the main thread.
    private func setError(_ error: Error) {
        let summary = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        let detail = (error as? CLIError)?.failureReason
        DispatchQueue.main.async { [weak self] in
            self?.lastError = summary
            self?.lastErrorDetail = detail
        }
    }

    /// Load the breakdowns for the analysis window over the current period.
    func loadAnalysis() {
        let period = self.period
        queue.async { [weak self] in
            do {
                // Dense + a calendar-aligned start so the daily chart shows exactly
                // N contiguous days (empty days as $0), matching the "N days" label.
                let since = Self.calendarSince(period)
                // Authoritative period total (same summary derivation the popover
                // uses), so the panel's total reconciles with the charts and popover.
                let summary = try CLIRunner.summary(since: since)
                let daily = try CLIRunner.rows(groupBy: "day", since: since, dense: true)
                // day,model composite for the stacked view (dense is single-dim only,
                // so gaps just render as missing columns here).
                let dailyByModel = try CLIRunner.rows(groupBy: "day,model", since: since)
                // Same `since` as the daily chart so every panel covers the identical
                // period — otherwise the by-model total wouldn't match the daily total
                // (calendar N days vs. a rolling Nd window differ at the boundary).
                let models = try CLIRunner.rows(groupBy: "model", since: since, sort: "cost")
                let projects = try CLIRunner.rows(groupBy: "project", since: since, sort: "cost", top: 8)
                DispatchQueue.main.async {
                    self?.periodSummary = summary
                    self?.dailyRows = daily
                    self?.dailyByModelRows = dailyByModel
                    self?.modelRows = models
                    self?.projectRows = projects
                    self?.lastError = nil
                    self?.lastErrorDetail = nil
                }
            } catch {
                self?.setError(error)
            }
        }
    }
}
