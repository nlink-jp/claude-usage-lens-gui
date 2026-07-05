import XCTest
@testable import ClaudeUsageLens

/// Tests the CLI-failure → friendly-summary mapping (issue #2). The raw stderr
/// stays available separately as `failureReason`.
final class CLIErrorTests: XCTestCase {
    func testCrashSummary() {
        let s = CLIError.summarize(exitCode: -1, crashed: true, stderr: "signal: killed")
        XCTAssertTrue(s.lowercased().contains("unexpectedly"), s)
    }

    func testPermissionSummary() {
        let s = CLIError.summarize(exitCode: 1, crashed: false, stderr: "open /Users/x/.claude: permission denied")
        XCTAssertTrue(s.lowercased().contains("permission"), s)
    }

    func testMissingPathSummary() {
        let s = CLIError.summarize(exitCode: 1, crashed: false, stderr: "stat /nope: no such file or directory")
        XCTAssertTrue(s.lowercased().contains("path"), s)
    }

    func testEmptyStderrMentionsExitCode() {
        let s = CLIError.summarize(exitCode: 2, crashed: false, stderr: "")
        XCTAssertTrue(s.contains("2"), s)
    }

    func testGenericLeadsWithFirstLine() {
        let s = CLIError.summarize(exitCode: 1, crashed: false, stderr: "unknown flag --wat\nusage: ...")
        XCTAssertTrue(s.contains("unknown flag --wat"), s)
        XCTAssertFalse(s.contains("usage:"), "should lead with only the first line")
    }

    func testFailureReasonCarriesRawDetail() {
        let e = CLIError.runFailed(summary: "friendly", detail: "raw stderr here")
        XCTAssertEqual(e.errorDescription, "friendly")
        XCTAssertEqual(e.failureReason, "raw stderr here")
    }

    func testBinaryNotFoundHasNoDetail() {
        XCTAssertNil(CLIError.binaryNotFound.failureReason)
    }
}
