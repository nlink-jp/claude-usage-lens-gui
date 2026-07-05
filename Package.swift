// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageLens",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageLens",
            path: "Sources/ClaudeUsageLens"
        ),
        .testTarget(
            name: "ClaudeUsageLensTests",
            dependencies: ["ClaudeUsageLens"],
            path: "Tests/ClaudeUsageLensTests"
        ),
    ]
)
