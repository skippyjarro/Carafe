// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Carafe",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CarafeCore"),
        .executableTarget(name: "Carafe", dependencies: ["CarafeCore"]),
        .testTarget(name: "CarafeCoreTests", dependencies: ["CarafeCore"]),
    ]
)
