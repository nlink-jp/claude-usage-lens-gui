import XCTest
@testable import ClaudeUsageLens

/// The unpriced badge: turns the store holds at $0 that should have cost
/// something. Pure state → text rules, so the wording never goes silent.
final class UnpricedTests: XCTestCase {
    private func summary(unpriced: Int?, models: [String: Int]?) -> Summary {
        let base = """
        {"first_day":"2026-09-02","last_day":"2026-09-02","active_days":1,"records":1,
         "input_tokens":1,"output_tokens":1,"cache_tokens":1,"total_usd":1,"daily_avg_usd":1,
         "peak_day":"2026-09-02","peak_usd":1,"projection_30d_usd":30
        """
        var extra = ""
        if let unpriced { extra += ",\"unpriced_records\":\(unpriced)" }
        if let models {
            let body = models.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
            extra += ",\"unpriced_models\":{\(body)}"
        }
        let data = (base + extra + "}").data(using: .utf8)!
        return try! JSONDecoder().decode(Summary.self, from: data)
    }

    func testStateFromSummary() {
        // Older CLI (no field) and a clean store both mean "no badge".
        XCTAssertNil(UsageModel.unpricedUsage(summary(unpriced: nil, models: nil)))
        XCTAssertNil(UsageModel.unpricedUsage(summary(unpriced: 0, models: [:])))
        // A count without a split still shows (the split is decoration).
        XCTAssertEqual(UsageModel.unpricedUsage(summary(unpriced: 3, models: nil)),
                       UnpricedUsage(records: 3, models: [:]))
        XCTAssertEqual(UsageModel.unpricedUsage(summary(unpriced: 67, models: ["claude-fable-5-1": 67])),
                       UnpricedUsage(records: 67, models: ["claude-fable-5-1": 67]))
    }

    func testLabelNamesCountAndModel() {
        XCTAssertEqual(UsageModel.unpricedLabel(UnpricedUsage(records: 67, models: ["claude-fable-5-1": 67])),
                       "67 turns on claude-fable-5-1 counted at $0")
        XCTAssertEqual(UsageModel.unpricedLabel(UnpricedUsage(records: 1, models: ["claude-fable-5-1": 1])),
                       "1 turn on claude-fable-5-1 counted at $0")
        XCTAssertEqual(UsageModel.unpricedLabel(UnpricedUsage(records: 5, models: ["a": 2, "b": 3])),
                       "5 turns on 2 models counted at $0")
        XCTAssertEqual(UsageModel.unpricedLabel(UnpricedUsage(records: 3, models: [:])),
                       "3 turns counted at $0")
    }

    func testHintNamesEveryPhaseAndItsWayOut() {
        // Every phase has a non-empty, distinct line — no silent state.
        let phases: [RepricePhase] = [.idle, .running, .done, .failed("claude-usage-lens crashed (exit 2)")]
        let hints = phases.map { UsageModel.unpricedHint(phase: $0) }
        XCTAssertTrue(hints.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(hints).count, hints.count)

        XCTAssertTrue(hints[0].contains("Reprice"))                 // idle: the button is the exit
        XCTAssertTrue(hints[0].contains("last 30 days"))            // the window the count covers
        XCTAssertTrue(hints[1].contains("Repricing"))               // running: say so
        XCTAssertTrue(hints[2].contains("Update the app"))          // done, still unpriced: next exit
        XCTAssertTrue(hints[3].contains("crashed (exit 2)"))        // failed: the reason, verbatim
    }

    func testMenuLabelMark() {
        XCTAssertEqual(UsageModel.menuLabel("$12.34", unpriced: false), "$12.34")
        XCTAssertEqual(UsageModel.menuLabel("$12.34", unpriced: true), "$12.34 ⚠︎")
        XCTAssertEqual(UsageModel.menuLabel("$116 · 58%", unpriced: true), "$116 · 58% ⚠︎")
    }
}
