// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Shirayuki",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Shirayuki", targets: ["Shirayuki"]),
    ],
    targets: [
        .target(
            name: "Shirayuki",
            path: "Shirayuki",
            exclude: ["Assets.xcassets", "ShirayukiApp.swift"],
            resources: [.process("NetworkRoutes.json")]
        ),
        .testTarget(
            name: "ShirayukiTests",
            dependencies: ["Shirayuki"],
            path: "ShirayukiTests"
        )
    ]
)
