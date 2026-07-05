import Foundation

/// UsageModel drives the UI: it periodically ingests and pulls today's summary
/// for the menu-bar label + popover, and loads the richer breakdowns for the
/// analysis window on demand. All CLI work runs off the main thread; @Published
/// mutations are hopped back to main.
final class UsageModel: ObservableObject {
    @Published var todaySummary: Summary?
    @Published var lastError: String?
    @Published var lastUpdated: Date?

    // Analysis window state
    @Published var period: String = "7d"
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

    /// Turn a "Nd" period into a UTC calendar start date (today − (N−1) days) as
    /// YYYY-MM-DD, so a dense daily series spans exactly N calendar days aligned to
    /// the CLI's UTC day buckets. Non-"Nd" periods pass through unchanged. `from`
    /// is injectable for testing.
    static func calendarSince(_ period: String, from now: Date = Date()) -> String {
        guard period.hasSuffix("d"), let n = Int(period.dropLast()), n > 0 else { return period }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let start = cal.date(byAdding: .day, value: -(n - 1), to: cal.startOfDay(for: now)) ?? now
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
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
                DispatchQueue.main.async {
                    self?.todaySummary = s
                    self?.lastError = nil
                    self?.lastUpdated = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                }
            }
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
                let daily = try CLIRunner.rows(groupBy: "day", since: since, dense: true)
                // day,model composite for the stacked view (dense is single-dim only,
                // so gaps just render as missing columns here).
                let dailyByModel = try CLIRunner.rows(groupBy: "day,model", since: since)
                let models = try CLIRunner.rows(groupBy: "model", since: period, sort: "cost")
                let projects = try CLIRunner.rows(groupBy: "project", since: period, sort: "cost", top: 8)
                DispatchQueue.main.async {
                    self?.dailyRows = daily
                    self?.dailyByModelRows = dailyByModel
                    self?.modelRows = models
                    self?.projectRows = projects
                    self?.lastError = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self?.lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
                }
            }
        }
    }
}
