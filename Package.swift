// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MediaBridge",
    platforms: [
        .iOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MediaBridge",
            targets: ["MediaBridge"]
        )
    ],
    targets: [
        .target(
            name: "MediaBridge",
            path: "Sources"
        ),
        .testTarget(
            name: "MediaBridgeTests",
            dependencies: ["MediaBridge"],
            path: "Tests"
        )
    ],
    swiftLanguageModes: [.v6]
)
