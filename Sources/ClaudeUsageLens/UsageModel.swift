import Foundation

/// UsageModel drives the UI: it periodically ingests and pulls today's summary
/// for the menu-bar label + popover, and loads the richer breakdowns for the
/// analysis window on demand. All CLI work runs off the main thread; @Published
/// mutations are hopped back to main.
final class UsageModel: ObservableObject {
    @Published var todaySummary: Summary?
    @Published var last30USD: Double?       // actual last-30-days total (matches the analysis panel)
    @Published var lastError: String?       // short, user-facing summary
    @Published var lastErrorDetail: String? // raw CLI output, shown smaller
    @Published var lastUpdated: Date?

    // Analysis window state
    @Published var period: String = "7d"
    @Published var periodSummary: Summary?  // total/tokens for the selected period (same summary derivation as the popover)
    @Published var dailyRows: [Row] = []
    @Published var dailyByModelRows: [Row] = [] // group-by day,model — for the stacked view
    @Published var modelRows: [Row] = []
    @Published var projectRows: [Row] = []

    private var timer: Timer?
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
        refreshToday()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshToday()
        }
    }

    /// Ingest (keep the store fresh), then pull today's summary.
    func refreshToday() {
        queue.async { [weak self] in
            do {
                try CLIRunner.ingest()
                let s = try CLIRunner.summary(since: "today")
                // Actual last-30-days total, on the same calendar window the
                // analysis panel uses, so the two reconcile.
                let last30 = try CLIRunner.summary(since: Self.calendarSince("30d"))
                DispatchQueue.main.async {
                    self?.todaySummary = s
                    self?.last30USD = last30.totalUSD
                    self?.lastError = nil
                    self?.lastErrorDetail = nil
                    self?.lastUpdated = Date()
                }
            } catch {
                self?.setError(error)
            }
        }
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
