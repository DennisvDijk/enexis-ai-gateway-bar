// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GatewayBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GatewayBar",
            path: "Sources/GatewayBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GatewayBarTests",
            dependencies: ["GatewayBar"],
            path: "Tests/GatewayBarTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
