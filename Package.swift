// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MinorSwiftCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MinorLog", targets: ["MinorLog"]),
        .library(name: "MinorKeychain", targets: ["MinorKeychain"]),
        .library(name: "MinorUpdater", targets: ["MinorUpdater"])
    ],
    targets: [
        .target(name: "MinorLog"),
        .target(name: "MinorKeychain"),
        .target(name: "MinorUpdater", dependencies: ["MinorLog"]),
        .testTarget(name: "MinorUpdaterTests", dependencies: ["MinorUpdater"])
    ]
)
