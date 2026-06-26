// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LyricX",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LyricXCore", targets: ["LyricXCore"]),
        .library(name: "LyricXMac", targets: ["LyricXMac"]),
        .library(name: "LyricXApp", targets: ["LyricXApp"]),
        .executable(name: "LyricX", targets: ["LyricX"]),
        .executable(name: "LyricXUnitTests", targets: ["LyricXUnitTests"])
    ],
    targets: [
        .target(name: "LyricXCore"),
        .target(
            name: "LyricXMac",
            dependencies: ["LyricXCore"]
        ),
        .target(
            name: "LyricXApp",
            dependencies: ["LyricXCore", "LyricXMac"],
            path: "Sources/LyricX",
            exclude: ["Resources/Info.plist", "App/LyricXApp.swift"]
        ),
        .executableTarget(
            name: "LyricX",
            dependencies: ["LyricXApp"],
            path: "Sources/LyricXExecutable"
        ),
        .executableTarget(
            name: "LyricXUnitTests",
            dependencies: ["LyricXApp", "LyricXCore", "LyricXMac"]
        )
    ]
)
