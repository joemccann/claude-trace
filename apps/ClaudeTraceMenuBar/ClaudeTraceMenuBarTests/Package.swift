// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeTraceMenuBarTests",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .testTarget(
            name: "ClaudeTraceMenuBarTests",
            path: "."
        ),
    ]
)
