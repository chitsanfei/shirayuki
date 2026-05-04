// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Shirayuki",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [
        .library(name: "Shirayuki", targets: ["Shirayuki"]),
    ],
    targets: [
        .target(
            name: "Shirayuki",
            path: "Shirayuki",
            exclude: ["Assets.xcassets"]
        ),
        .testTarget(
            name: "ShirayukiTests",
            dependencies: ["Shirayuki"],
            path: "ShirayukiTests"
        )
    ]
)
