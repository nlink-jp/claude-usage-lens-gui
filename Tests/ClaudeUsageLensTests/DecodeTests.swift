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

    func testCompactFormatting() {
        XCTAssertEqual(PopoverView.compact(500), "500")
        XCTAssertEqual(PopoverView.compact(12_345), "12.3K")
        XCTAssertEqual(PopoverView.compact(1_234_567), "1.2M")
    }
}
