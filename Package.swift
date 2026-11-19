// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LoomaWord",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LoomaWord", targets: ["LoomaWordLauncher"]),
        .library(name: "LoomaWordLib", type: .dynamic, targets: ["LoomaWordLib"])
    ],
    targets: [
        .target(
            name: "LoomaWordLib",
            dependencies: [],
            path: "Sources/LoomaWordLib",
            linkerSettings: [
                // Carbon `RegisterEventHotKey` for global hotkeys (no Accessibility permission).
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "LoomaWordLauncher",
            dependencies: ["LoomaWordLib"],
            path: "Sources/LoomaWordLauncher"
        ),
        .testTarget(
            name: "LoomaWordLibTests",
            dependencies: ["LoomaWordLib"],
            path: "Tests/LoomaWordLibTests"
        )
    ]
)
