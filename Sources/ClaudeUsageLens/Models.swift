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
    }
}
