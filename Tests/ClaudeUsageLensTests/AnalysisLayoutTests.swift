import XCTest
@testable import ClaudeUsageLens

/// The analysis window's label rules: what tests can pin of "labels must not
/// print over each other". The drawing itself is checked on screen.
final class AnalysisLayoutTests: XCTestCase {
    // 13 days at a step of 2 picks the 13th anyway; 14 days picks the 13th by
    // step and then the 14th as "always the last" — two labels one day apart.
    func testLastDayLabelReplacesANeighbourItWouldCollideWith() {
        func days(_ n: Int) -> [String] { (1...n).map { String(format: "d%02d", $0) } }
        XCTAssertEqual(AnalysisView.axisDayLabels(days(13)), ["d01", "d03", "d05", "d07", "d09", "d11", "d13"])
        XCTAssertEqual(AnalysisView.axisDayLabels(days(14)), ["d01", "d03", "d05", "d07", "d09", "d11", "d14"])
        // 90 days, step 8: the step lands on d89, one day before the end.
        let quarter = AnalysisView.axisDayLabels(days(90))
        XCTAssertEqual(quarter.suffix(2), ["d81", "d90"])
        XCTAssertEqual(quarter.first, "d01")
        // A gap of more than half a step keeps both.
        XCTAssertEqual(AnalysisView.axisDayLabels(days(30)).suffix(2), ["d28", "d30"])
    }

    func testBarFraction() {
        XCTAssertEqual(AnalysisView.barFraction(50, peak: 200), 0.25)
        XCTAssertEqual(AnalysisView.barFraction(200, peak: 200), 1)
        XCTAssertEqual(AnalysisView.barFraction(0, peak: 200), 0)
        XCTAssertEqual(AnalysisView.barFraction(0, peak: 0), 0)   // an all-zero period draws no bar
        XCTAssertEqual(AnalysisView.barFraction(-1, peak: 200), 0)
    }
}
