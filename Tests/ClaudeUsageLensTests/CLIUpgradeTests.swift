import XCTest
@testable import ClaudeUsageLens

/// The reprice-on-CLI-change rule: which `--version` outputs count, and when
/// a pass is due.
final class CLIUpgradeTests: XCTestCase {
    func testParseVersion() {
        XCTAssertEqual(CLIUpgrade.parseVersion("claude-usage-lens v0.9.0\n"), "v0.9.0")
        XCTAssertEqual(CLIUpgrade.parseVersion("claude-usage-lens v0.9.0-2-gabc1234-dirty"), "v0.9.0-2-gabc1234-dirty")
        // Anything else is not trusted as a version.
        XCTAssertNil(CLIUpgrade.parseVersion(""))
        XCTAssertNil(CLIUpgrade.parseVersion("v0.9.0"))
        XCTAssertNil(CLIUpgrade.parseVersion("something-else v0.9.0"))
        XCTAssertNil(CLIUpgrade.parseVersion("claude-usage-lens v0.9.0 extra"))
    }

    func testShouldReprice() {
        // Upgraded CLI, and an install that has never recorded a pass.
        XCTAssertTrue(CLIUpgrade.shouldReprice(current: "v0.9.0", lastRepriced: "v0.8.1"))
        XCTAssertTrue(CLIUpgrade.shouldReprice(current: "v0.9.0", lastRepriced: nil))
        // A downgrade changes the rates just the same.
        XCTAssertTrue(CLIUpgrade.shouldReprice(current: "v0.8.1", lastRepriced: "v0.9.0"))
        // Same CLI: already repriced.
        XCTAssertFalse(CLIUpgrade.shouldReprice(current: "v0.9.0", lastRepriced: "v0.9.0"))
        // Unreadable version: do nothing.
        XCTAssertFalse(CLIUpgrade.shouldReprice(current: nil, lastRepriced: "v0.8.1"))
        XCTAssertFalse(CLIUpgrade.shouldReprice(current: nil, lastRepriced: nil))
    }

    func testLogLineNamesTheRetry() {
        let line = CLIUpgrade.logLine(error: CLIError.binaryNotFound)
        XCTAssertTrue(line.hasPrefix("claude-usage-lens-gui: reprice after a CLI change failed"))
        XCTAssertTrue(line.hasSuffix("will retry at next launch"))
    }
}
