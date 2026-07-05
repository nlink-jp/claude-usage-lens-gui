import Foundation

enum CLIError: LocalizedError {
    case binaryNotFound
    case launchFailed(detail: String)
    case runFailed(summary: String, detail: String)

    /// A short, user-facing summary (shown prominently).
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "claude-usage-lens CLI not found. Reinstall ClaudeUsageLens.app (the CLI ships bundled), or install claude-usage-lens on your PATH."
        case .launchFailed:
            return "Couldn't start the claude-usage-lens CLI. Reinstall the app if this keeps happening."
        case .runFailed(let summary, _):
            return summary
        }
    }

    /// The raw CLI output (shown as smaller secondary detail), if any.
    var failureReason: String? {
        switch self {
        case .binaryNotFound: return nil
        case .launchFailed(let d): return d.isEmpty ? nil : d
        case .runFailed(_, let d): return d.isEmpty ? nil : d
        }
    }

    /// Translate a CLI failure into a short, actionable summary. Pure (testable):
    /// the raw stderr stays available separately as the detail.
    static func summarize(exitCode: Int32, crashed: Bool, stderr: String) -> String {
        let s = stderr.lowercased()
        if crashed {
            return "The usage CLI stopped unexpectedly. Try Refresh; if it keeps happening, reinstall the app."
        }
        if s.contains("permission denied") || s.contains("operation not permitted") {
            return "Couldn't read your Claude logs (permission denied). Check that the app can access ~/.claude and Claude's local sessions."
        }
        if s.contains("no such file") || s.contains("cannot find") {
            return "A required path wasn't found. Run Claude Code or Cowork first, or verify the CLI's source paths (claude-usage-lens doctor)."
        }
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "The usage CLI exited with an error (code \(exitCode))."
        }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return "The usage CLI reported: \(firstLine)"
    }
}

/// CLIRunner locates and invokes the claude-usage-lens CLI, decoding its --json
/// output. The CLI is the single source of truth for parsing/pricing/aggregation;
/// this GUI is a thin front-end over it.
enum CLIRunner {
    /// Resolve the CLI binary. The **bundled** copy in the .app's Resources is the
    /// trust anchor: it ships Developer-ID signed + notarized, so it can't be
    /// swapped without invalidating the signature. In a release build that comes
    /// first and an environment variable can't redirect execution elsewhere; the
    /// only fallbacks are the conventional install locations (used when the CLI
    /// isn't bundled — see the Makefile). In DEBUG builds the `$CLAUDE_USAGE_LENS_BIN`
    /// override and the local dev path are honored for convenience.
    static func findBinary() -> String? {
        var allowEnvOverride = false
        var devPaths: [String] = []
        #if DEBUG
        allowEnvOverride = true
        devPaths = [NSHomeDirectory() + "/works/nlink-jp/util-series/claude-usage-lens/dist/claude-usage-lens"]
        #endif
        return resolveBinary(
            env: ProcessInfo.processInfo.environment,
            allowEnvOverride: allowEnvOverride,
            bundled: Bundle.main.resourceURL?.appendingPathComponent("claude-usage-lens").path,
            devPaths: devPaths,
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }

    /// Pure resolution logic (injectable for tests). Order:
    ///   [env, only if `allowEnvOverride`] → bundled → /usr/local, /opt/homebrew → [devPaths]
    /// Returns the first path that `isExecutable` accepts. Keeping the bundled
    /// binary ahead of everything except a DEBUG-only override means a poisoned
    /// `$CLAUDE_USAGE_LENS_BIN` can't take precedence over the signed bundle in a
    /// release build.
    static func resolveBinary(
        env: [String: String],
        allowEnvOverride: Bool,
        bundled: String?,
        devPaths: [String],
        isExecutable: (String) -> Bool
    ) -> String? {
        var order: [String] = []
        if allowEnvOverride, let p = env["CLAUDE_USAGE_LENS_BIN"] {
            order.append(p)
        }
        if let bundled {
            order.append(bundled)
        }
        order += ["/usr/local/bin/claude-usage-lens", "/opt/homebrew/bin/claude-usage-lens"]
        order += devPaths
        return order.first(where: isExecutable)
    }

    @discardableResult
    static func run(_ args: [String]) throws -> Data {
        guard let bin = findBinary() else { throw CLIError.binaryNotFound }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
        } catch {
            throw CLIError.launchFailed(detail: error.localizedDescription)
        }
        // Read stdout to EOF (unblocks when the process exits), then reap.
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let stderr = String(
                data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let crashed = proc.terminationReason == .uncaughtSignal
            throw CLIError.runFailed(
                summary: CLIError.summarize(exitCode: proc.terminationStatus, crashed: crashed, stderr: stderr),
                detail: stderr
            )
        }
        return data
    }

    // MARK: - Typed queries

    static func ingest() throws {
        _ = try run(["ingest"])
    }

    static func summary(since: String) throws -> Summary {
        let data = try run(["report", "--since", since, "--summary", "--json"])
        return try JSONDecoder().decode(Summary.self, from: data)
    }

    static func rows(groupBy: String, since: String? = nil, sort: String? = nil, top: Int? = nil, dense: Bool = false) throws -> [Row] {
        var args = ["report", "--group-by", groupBy, "--json"]
        if let since { args += ["--since", since] }
        if let sort { args += ["--sort", sort] }
        if let top { args += ["--top", String(top)] }
        if dense { args += ["--dense"] }
        return try JSONDecoder().decode([Row].self, from: try run(args))
    }
}
