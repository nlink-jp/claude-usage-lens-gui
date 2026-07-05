import Foundation

enum CLIError: LocalizedError {
    case binaryNotFound
    case runFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "claude-usage-lens binary not found. Install it on PATH, or set CLAUDE_USAGE_LENS_BIN."
        case .runFailed(let msg):
            return msg.isEmpty ? "claude-usage-lens exited with an error." : msg
        }
    }
}

/// CLIRunner locates and invokes the claude-usage-lens CLI, decoding its --json
/// output. The CLI is the single source of truth for parsing/pricing/aggregation;
/// this GUI is a thin front-end over it.
enum CLIRunner {
    /// Resolve the CLI binary: explicit env override, then the bundled copy in
    /// the .app's Resources, then common install / dev locations.
    static func findBinary() -> String? {
        let fm = FileManager.default
        if let p = ProcessInfo.processInfo.environment["CLAUDE_USAGE_LENS_BIN"],
           fm.isExecutableFile(atPath: p) {
            return p
        }
        if let res = Bundle.main.resourceURL?.appendingPathComponent("claude-usage-lens").path,
           fm.isExecutableFile(atPath: res) {
            return res
        }
        let home = NSHomeDirectory()
        let candidates = [
            "/usr/local/bin/claude-usage-lens",
            "/opt/homebrew/bin/claude-usage-lens",
            home + "/works/nlink-jp/util-series/claude-usage-lens/dist/claude-usage-lens",
        ]
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) })
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
        try proc.run()
        // Read stdout to EOF (unblocks when the process exits), then reap.
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let err = String(
                data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8) ?? ""
            throw CLIError.runFailed(err.trimmingCharacters(in: .whitespacesAndNewlines))
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

    static func rows(groupBy: String, since: String? = nil, sort: String? = nil, top: Int? = nil) throws -> [Row] {
        var args = ["report", "--group-by", groupBy, "--json"]
        if let since { args += ["--since", since] }
        if let sort { args += ["--sort", sort] }
        if let top { args += ["--top", String(top)] }
        return try JSONDecoder().decode([Row].self, from: try run(args))
    }
}
