// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenSoundSource",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenSoundSource",
            targets: ["OpenSoundSource"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenSoundSource",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFAudio"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "OpenSoundSourceTests",
            dependencies: ["OpenSoundSource"],
            path: "Tests"
        )
    ]
)
