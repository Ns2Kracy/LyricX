// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LyricX",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LyricXCore", targets: ["LyricXCore"]),
        .executable(name: "LyricX", targets: ["LyricX"]),
        .executable(name: "LyricXUnitTests", targets: ["LyricXUnitTests"])
    ],
    targets: [
        .target(name: "LyricXCore"),
        .executableTarget(
            name: "LyricX",
            dependencies: ["LyricXCore"],
            exclude: ["Resources/Info.plist"]
        ),
        .executableTarget(
            name: "LyricXUnitTests",
            dependencies: ["LyricXCore"]
        )
    ]
)
