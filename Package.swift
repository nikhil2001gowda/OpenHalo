// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenHalo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenHalo",
            targets: ["OpenHalo"]
        ),
        .executable(
            name: "OpenHaloVerify",
            targets: ["OpenHaloVerify"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OpenHaloKit",
            dependencies: [],
            path: "Sources/OpenHalo",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .executableTarget(
            name: "OpenHalo",
            dependencies: ["OpenHaloKit"],
            path: "Sources/OpenHaloApp",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .executableTarget(
            name: "OpenHaloVerify",
            dependencies: ["OpenHaloKit"],
            path: "Sources/OpenHaloVerify"
        )
    ]
)
