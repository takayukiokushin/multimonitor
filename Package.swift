// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OLEDGuard",
    platforms: [.macOS("27.0")],
    targets: [
        // UI に依存しないロジック(設定モデル、後のステップで無操作判定)。テスト対象。
        .target(
            name: "OLEDGuardCore",
            path: "Sources/OLEDGuardCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "OLEDGuard",
            dependencies: ["OLEDGuardCore"],
            path: "Sources/OLEDGuard",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
