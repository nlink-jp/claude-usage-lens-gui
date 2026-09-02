import Foundation

/// Row mirrors one JSON object from `claude-usage-lens report --json`.
struct Row: Codable, Identifiable {
    let key: String
    let records: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int
    let cacheTokens: Int
    let costUSD: Double

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, records
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
        case cacheTokens = "cache_tokens"
        case costUSD = "cost_usd"
    }
}

/// LimitsPayload mirrors `claude-usage-lens limits --json` (CLI ADR-0001):
/// the calibrated weekly-quota state derived from an official /usage reading.
/// `calibrated == false` (no status) means "no usable calibration yet" — the
/// app then falls back to the user's assumed budget.
struct LimitsPayload: Codable {
    let calibrated: Bool
    let status: LimitsStatus?
}

struct LimitsStatus: Codable {
    struct Amounts: Codable {
        let costUSD: Double
        let tokens: Int

        enum CodingKeys: String, CodingKey {
            case costUSD = "cost_usd"
            case tokens
        }
    }

    struct CalibrationInfo: Codable {
        let observedAt: Date
        let resetsAt: Date
        let utilizationPct: Double
        let source: String
        let ageDays: Double

        enum CodingKeys: String, CodingKey {
            case observedAt = "observed_at"
            case resetsAt = "resets_at"
            case utilizationPct = "utilization_pct"
            case source
            case ageDays = "age_days"
        }
    }

    let window: String
    let windowStart: Date
    let windowEnd: Date
    let calibration: CalibrationInfo
    let caps: Amounts
    let consumed: Amounts
    let remaining: Amounts

    enum CodingKeys: String, CodingKey {
        case window
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case calibration, caps, consumed, remaining
    }
}

/// CalibrateResult mirrors `claude-usage-lens calibrate add --json`.
struct CalibrateResult: Codable {
    let id: Int
    let caps: LimitsStatus.Amounts
}

/// Summary mirrors `claude-usage-lens report --summary --json`.
struct Summary: Codable {
    let firstDay: String
    let lastDay: String
    let activeDays: Int
    let records: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let totalUSD: Double
    let dailyAvgUSD: Double
    let peakDay: String
    let peakUSD: Double
    let projection30USD: Double

    /// Claude Code records in the period that carry tokens yet are stored at
    /// $0 — a model the CLI could not price when it ingested them, or a rate
    /// table updated since without a `reprice` (CLI ≥ 0.7.0). Optional so a
    /// summary from an older CLI on PATH still decodes.
    let unpricedRecords: Int?
    let unpricedModels: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case firstDay = "first_day"
        case lastDay = "last_day"
        case activeDays = "active_days"
        case records
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheTokens = "cache_tokens"
        case totalUSD = "total_usd"
        case dailyAvgUSD = "daily_avg_usd"
        case peakDay = "peak_day"
        case peakUSD = "peak_usd"
        case projection30USD = "projection_30d_usd"
        case unpricedRecords = "unpriced_records"
        case unpricedModels = "unpriced_models"
    }
}

/// Usage the store holds at $0 although it should have cost something: turns
/// on a model the bundled CLI's rate table did not know when they were
/// ingested, or that a newer table now prices but `reprice` has not yet
/// touched. Every figure the app shows understates by these turns.
struct UnpricedUsage: Equatable {
    let records: Int
    let models: [String: Int]   // model id → record count
}

/// Where the Reprice button's attempt stands, for the current badge episode.
/// A Bool cannot say "running" or "failed", and both must be named on screen.
enum RepricePhase: Equatable {
    case idle
    case running
    case done                 // reprice completed; the badge (if still up) is beyond it
    case failed(String)       // the CLI failed; the reason, as the user should read it
}
