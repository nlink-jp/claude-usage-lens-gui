import Foundation

/// Reprice the stored history once whenever the bundled CLI changes.
///
/// The store keeps the cost each row was computed with, and ingest is
/// incremental, so a new CLI's rates reach only the turns it ingests itself.
/// The unpriced badge catches a model the old CLI stored at $0, but not a rate
/// it got wrong — Claude Sonnet 5.5's cache reads were stored at 2× until CLI
/// v0.9.0 — so nothing on screen would ever prompt a reprice for those rows.
/// Repricing on every CLI change closes that gap; `reprice` is idempotent and
/// leaves Cowork rows alone, so a redundant pass costs only its few seconds.
enum CLIUpgrade {
    /// The CLI version the store was last repriced with (UserDefaults, String).
    static let defaultsKey = "lastRepricedCLIVersion"

    /// The CLI's `--version` output ("claude-usage-lens v0.9.0") → "v0.9.0".
    /// nil when the output is not that shape — no reprice is better than one
    /// keyed on a string we cannot interpret.
    static func parseVersion(_ output: String) -> String? {
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0] == "claude-usage-lens" else { return nil }
        return String(parts[1])
    }

    /// Whether to reprice: the CLI reported a version other than the one the
    /// store was last repriced with. No record — an install from before this
    /// existed, or a fresh one — counts as a change.
    static func shouldReprice(current: String?, lastRepriced: String?) -> Bool {
        guard let current else { return false }
        return current != lastRepriced
    }

    /// The stderr line for a failed pass; it is retried at the next launch.
    static func logLine(error: Error) -> String {
        let why = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        return "claude-usage-lens-gui: reprice after a CLI change failed (\(why)) — will retry at next launch"
    }
}
