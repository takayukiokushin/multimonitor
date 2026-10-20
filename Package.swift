// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OLEDGuard",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(
            name: "OLEDGuard",
            path: "Sources/OLEDGuard",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
