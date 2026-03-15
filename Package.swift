// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TinyAgent",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "TinyAgentCore", targets: ["TinyAgentCore"]),
        .library(name: "TinyAgent", targets: ["TinyAgent"]),
        .library(name: "TinyAgentOpenAI", targets: ["TinyAgentOpenAI"]),
        .executable(name: "tiny-agent-cli", targets: ["TinyAgentCLI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TinyAgentCore",
            path: "Sources/Core"
        ),
        .target(
            name: "TinyAgent",
            dependencies: ["TinyAgentCore"],
            path: "Sources/TinyAgent"
        ),
        .target(
            name: "TinyAgentOpenAI",
            dependencies: ["TinyAgentCore"],
            path: "Sources/OpenAI"
        ),
        .executableTarget(
            name: "TinyAgentCLI",
            dependencies: ["TinyAgent"],
            path: "Sources/CLI"
        ),
        .testTarget(
            name: "TinyAgentTests",
            dependencies: ["TinyAgent"],
            path: "Tests/TinyAgentTests"
        )
    ]
)
