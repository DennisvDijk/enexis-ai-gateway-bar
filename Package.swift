// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "GatewayBar",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "GatewayBar", path: "Sources/GatewayBar")]
)
