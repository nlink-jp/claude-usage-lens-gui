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
    @Published var modelRows: [Row] = []
    @Published var projectRows: [Row] = []

    private var timer: Timer?
    private let queue = DispatchQueue(label: "jp.nlink.claude-usage-lens-gui.cli", qos: .utility)

    /// The compact text shown in the menu bar.
    var menuBarLabel: String {
        if let s = todaySummary { return String(format: "$%.2f", s.totalUSD) }
        if lastError != nil { return "—" }
        return "…"
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
                let daily = try CLIRunner.rows(groupBy: "day", since: period)
                let models = try CLIRunner.rows(groupBy: "model", since: period, sort: "cost")
                let projects = try CLIRunner.rows(groupBy: "project", since: period, sort: "cost", top: 8)
                DispatchQueue.main.async {
                    self?.dailyRows = daily
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
