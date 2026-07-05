import XCTest
@testable import ClaudeUsageLens

/// Trust-boundary tests for CLI binary resolution (issue #1). The security-
/// relevant behaviour is that the bundled binary is the trust anchor and a
/// poisoned $CLAUDE_USAGE_LENS_BIN cannot take precedence in a release build
/// (allowEnvOverride == false).
final class BinaryResolutionTests: XCTestCase {
    private let bundled = "/Applications/ClaudeUsageLens.app/Contents/Resources/claude-usage-lens"
    private let brew = "/opt/homebrew/bin/claude-usage-lens"
    private let usrLocal = "/usr/local/bin/claude-usage-lens"

    func testReleaseIgnoresEnvOverride() {
        // Release semantics: env override disabled. Even if $CLAUDE_USAGE_LENS_BIN
        // points at an executable, the bundled binary must win.
        let got = CLIRunner.resolveBinary(
            env: ["CLAUDE_USAGE_LENS_BIN": "/tmp/evil"],
            allowEnvOverride: false,
            bundled: bundled,
            devPaths: [],
            isExecutable: { $0 == "/tmp/evil" || $0 == bundled }
        )
        XCTAssertEqual(got, bundled)
    }

    func testDebugHonorsEnvOverride() {
        let got = CLIRunner.resolveBinary(
            env: ["CLAUDE_USAGE_LENS_BIN": "/tmp/override"],
            allowEnvOverride: true,
            bundled: bundled,
            devPaths: [],
            isExecutable: { $0 == "/tmp/override" || $0 == bundled }
        )
        XCTAssertEqual(got, "/tmp/override")
    }

    func testBundledPreferredOverPath() {
        let got = CLIRunner.resolveBinary(
            env: [:],
            allowEnvOverride: false,
            bundled: bundled,
            devPaths: [],
            isExecutable: { _ in true } // everything executable
        )
        XCTAssertEqual(got, bundled, "bundled binary must be preferred over PATH")
    }

    func testFallsBackToPathWhenBundleMissing() {
        let got = CLIRunner.resolveBinary(
            env: [:],
            allowEnvOverride: false,
            bundled: bundled,
            devPaths: [],
            isExecutable: { $0 == brew } // only homebrew present
        )
        XCTAssertEqual(got, brew)
    }

    func testUsrLocalBeforeHomebrew() {
        let got = CLIRunner.resolveBinary(
            env: [:],
            allowEnvOverride: false,
            bundled: nil,
            devPaths: [],
            isExecutable: { $0 == usrLocal || $0 == brew }
        )
        XCTAssertEqual(got, usrLocal)
    }

    func testNilWhenNothingExecutable() {
        let got = CLIRunner.resolveBinary(
            env: ["CLAUDE_USAGE_LENS_BIN": "/tmp/evil"],
            allowEnvOverride: true,
            bundled: bundled,
            devPaths: ["/dev/path"],
            isExecutable: { _ in false }
        )
        XCTAssertNil(got)
    }
}
