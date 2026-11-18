// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReaDeepL",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ReaDeepL", targets: ["ReaDeepLLauncher"]),
        .library(name: "ReaDeepLLib", type: .dynamic, targets: ["ReaDeepLLib"])
    ],
    targets: [
        .target(
            name: "ReaDeepLLib",
            path: "Sources/ReaDeepLLib"
        ),
        .executableTarget(
            name: "ReaDeepLLauncher",
            dependencies: ["ReaDeepLLib"],
            path: "Sources/ReaDeepLLauncher"
        )
    ]
)
