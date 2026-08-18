import XCTest
@testable import ClaudeUsageLens

final class DecodeTests: XCTestCase {
    func testDecodeSummary() throws {
        let json = """
        {"first_day":"2026-07-01","last_day":"2026-07-05","active_days":4,"records":1403,
         "input_tokens":1012427,"output_tokens":1384256,"cache_tokens":386681822,
         "total_usd":486.42,"daily_avg_usd":121.61,"peak_day":"2026-07-04",
         "peak_usd":278.10,"projection_30d_usd":3648.16}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(Summary.self, from: json)
        XCTAssertEqual(s.activeDays, 4)
        XCTAssertEqual(s.records, 1403)
        XCTAssertEqual(s.totalUSD, 486.42, accuracy: 0.001)
        XCTAssertEqual(s.peakDay, "2026-07-04")
        XCTAssertEqual(s.projection30USD, 3648.16, accuracy: 0.001)
    }

    func testDecodeRows() throws {
        let json = """
        [{"key":"claude-opus-4-8","records":10,"input_tokens":100,"output_tokens":50,
          "cache_read_tokens":5,"cache_write_tokens":3,"cache_tokens":8,"cost_usd":1.25}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([Row].self, from: json)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].key, "claude-opus-4-8")
        XCTAssertEqual(rows[0].cacheReadTokens, 5)
        XCTAssertEqual(rows[0].costUSD, 1.25, accuracy: 0.001)
        XCTAssertEqual(rows[0].id, "claude-opus-4-8")
    }

    // Contract test for `limits --json` (CLI ADR-0001): the calibrated payload,
    // with RFC3339 whole-second timestamps, and the uncalibrated fallback form.
    func testDecodeLimitsPayload() throws {
        let json = """
        {"calibrated":true,
         "status":{
           "window":"weekly",
           "window_start":"2026-08-07T09:00:00Z",
           "window_end":"2026-08-14T09:00:00Z",
           "calibration":{"observed_at":"2026-08-08T02:01:00Z","resets_at":"2026-08-14T09:00:00Z",
                          "utilization_pct":50,"source":"manual","age_days":0.4},
           "caps":{"cost_usd":60.54,"tokens":304824},
           "consumed":{"cost_usd":30.27,"tokens":152412},
           "utilization_cost_pct":50.0,"utilization_tokens_pct":50.0,
           "remaining":{"cost_usd":30.27,"tokens":152412}}}
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let p = try dec.decode(LimitsPayload.self, from: json)
        XCTAssertTrue(p.calibrated)
        let st = try XCTUnwrap(p.status)
        XCTAssertEqual(st.window, "weekly")
        XCTAssertEqual(st.caps.costUSD, 60.54, accuracy: 0.001)
        XCTAssertEqual(st.caps.tokens, 304_824)
        XCTAssertEqual(st.consumed.costUSD, 30.27, accuracy: 0.001)
        XCTAssertEqual(st.remaining.tokens, 152_412)
        XCTAssertEqual(st.calibration.utilizationPct, 50, accuracy: 0.001)
        XCTAssertEqual(st.calibration.source, "manual")
        XCTAssertEqual(st.windowEnd.timeIntervalSince(st.windowStart), 7 * 86_400, accuracy: 1)

        let none = try dec.decode(LimitsPayload.self,
                                  from: #"{"calibrated":false,"reason":"no calibration recorded"}"#.data(using: .utf8)!)
        XCTAssertFalse(none.calibrated)
        XCTAssertNil(none.status)
    }

    func testDecodeCalibrateResult() throws {
        let json = #"{"id":3,"caps":{"cost_usd":120.5,"tokens":600000}}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(CalibrateResult.self, from: json)
        XCTAssertEqual(r.id, 3)
        XCTAssertEqual(r.caps.costUSD, 120.5, accuracy: 0.001)
    }

    func testCompactFormatting() {
        XCTAssertEqual(PopoverView.compact(500), "500")
        XCTAssertEqual(PopoverView.compact(12_345), "12.3K")
        XCTAssertEqual(PopoverView.compact(1_234_567), "1.2M")
    }

    func testAxisDayLabels() {
        // Short ranges pass through unchanged.
        let week = (1...7).map { String(format: "2026-07-%02d", $0) }
        XCTAssertEqual(AnalysisView.axisDayLabels(week), week)

        // Long ranges are thinned to ~maxLabels, keeping first and last.
        let quarter = (1...90).map { String(format: "d%02d", $0) }
        let thinned = AnalysisView.axisDayLabels(quarter, maxLabels: 12)
        XCTAssertLessThanOrEqual(thinned.count, 14)
        XCTAssertGreaterThan(thinned.count, 8)
        XCTAssertEqual(thinned.first, quarter.first)
        XCTAssertEqual(thinned.last, quarter.last)
    }

    func testUniqueShortLabels() {
        // Same basename under different parents ⇒ disambiguated with parent.
        let keys = [
            "/Users/you/src/example-org/util-series/voice-studio-mcp",
            "/Users/you/src/example-org/_wip/voice-studio-mcp",
            "/Users/you/src/example-org",
            "claude-opus-4-8",
        ]
        let labels = AnalysisView.uniqueShortLabels(keys)
        XCTAssertEqual(labels[keys[0]], "util-series/voice-studio-mcp")
        XCTAssertEqual(labels[keys[1]], "_wip/voice-studio-mcp")
        XCTAssertEqual(labels[keys[2]], "example-org") // unique basename ⇒ basename
        XCTAssertEqual(labels[keys[3]], "claude-opus-4-8") // non-path passes through
        // All labels are unique — no two bars collapse.
        XCTAssertEqual(Set(labels.values).count, keys.count)
    }

    func testShortDay() {
        XCTAssertEqual(AnalysisView.shortDay("2026-07-05"), "07-05")
        XCTAssertEqual(AnalysisView.shortDay("unknown"), "unknown")
        XCTAssertEqual(AnalysisView.shortDay("2026-W27"), "2026-W27")
    }

    func testCalendarSince() {
        // 2026-07-05 18:00 in UTC with "7d" ⇒ start = today − 6 days = 2026-06-29.
        let utc = TimeZone(identifier: "UTC")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 18))!
        XCTAssertEqual(UsageModel.calendarSince("7d", from: now, tz: utc), "2026-06-29")
        XCTAssertEqual(UsageModel.calendarSince("30d", from: now, tz: utc), "2026-06-06")
        XCTAssertEqual(UsageModel.calendarSince("1d", from: now, tz: utc), "2026-07-05")
        // Non-"Nd" periods pass through unchanged.
        XCTAssertEqual(UsageModel.calendarSince("today", from: now, tz: utc), "today")
        XCTAssertEqual(UsageModel.calendarSince("2026-07-01", from: now, tz: utc), "2026-07-01")
    }

    func testCalendarSinceUsesGivenZone() {
        // 2026-07-05 18:00 UTC == 2026-07-06 03:00 JST → "today" differs by zone.
        let utc = TimeZone(identifier: "UTC")!
        let jst = TimeZone(identifier: "Asia/Tokyo")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 18))!
        XCTAssertEqual(UsageModel.calendarSince("1d", from: now, tz: utc), "2026-07-05")
        XCTAssertEqual(UsageModel.calendarSince("1d", from: now, tz: jst), "2026-07-06")
    }
}

/// The version shown in the popover — a menu-bar app's only way to say which
/// build it is.
final class AppVersionTests: XCTestCase {
    func testShownVerbatim() {
        XCTAssertEqual(AppVersion.display("v0.2.1"), "v0.2.1")
        // git describe's precision is the point: don't trim it away.
        XCTAssertEqual(AppVersion.display("v0.2.1-3-gabc1234"), "v0.2.1-3-gabc1234")
        XCTAssertEqual(AppVersion.display("v0.2.1-dirty"), "v0.2.1-dirty")
    }

    func testFallsBackToDev() {
        XCTAssertEqual(AppVersion.display(nil), "dev")          // outside a bundle
        XCTAssertEqual(AppVersion.display(""), "dev")
        XCTAssertEqual(AppVersion.display("  "), "dev")
        XCTAssertEqual(AppVersion.display("${VERSION}"), "dev") // unsubstituted placeholder
    }
}
