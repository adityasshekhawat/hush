// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "HushCore", targets: ["HushCore"]),
        .executable(name: "Hush", targets: ["Hush"]),
        .executable(name: "hushctl", targets: ["hushctl"]),
    ],
    targets: [
        // Decision engine. No UI, no Apple-only frameworks beyond Foundation + SQLite,
        // so it stays testable and portable (PRD: "Built to extend").
        .target(
            name: "HushCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // macOS adapters: EventKit calendar source, focus detection.
        .target(
            name: "HushMac",
            dependencies: ["HushCore"]
        ),
        // The overlay app (menu bar + transparent character panel).
        .executableTarget(
            name: "Hush",
            dependencies: ["HushCore", "HushMac"],
            exclude: ["Info.plist"]
        ),
        // Tiny helper Claude Code hooks run: forwards a thin status event to Hush (docs/agent-plan.md, Phase 1).
        .executableTarget(name: "hushctl", dependencies: ["HushCore"]),
        // Ask Hush eval: runs evals/asks.json through a lane with a real model (docs/lanes-plan.md § L2).
        .executableTarget(name: "hush-eval", dependencies: ["HushCore", "HushMac"]),
        .testTarget(
            name: "HushCoreTests",
            dependencies: ["HushCore"]
        ),
    ]
)
