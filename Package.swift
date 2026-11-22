// swift-tools-version: 6.0
import PackageDescription

let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "GatewayBar",
    platforms: [.macOS(.v14)],
    targets: [
        // All app logic and views; the app target is only the @main entry point.
        .target(name: "GatewayBarKit", path: "Sources/GatewayBarKit", swiftSettings: v5),
        .executableTarget(name: "GatewayBar", dependencies: ["GatewayBarKit"], path: "Sources/GatewayBar", swiftSettings: v5),
        // UI test runner: hosts the real views, reads the accessibility tree and presses buttons.
        // Plain executable so it runs everywhere (`swift run UICheck`), also without Xcode.
        .executableTarget(name: "UICheck", dependencies: ["GatewayBarKit"], path: "Sources/UICheck", swiftSettings: v5),
        .testTarget(name: "GatewayBarTests", dependencies: ["GatewayBarKit"], path: "Tests/GatewayBarTests", swiftSettings: v5),
    ]
)
