// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SoundPref",
    platforms: [
        .macOS("14.2")
    ],
    products: [
        .executable(
            name: "SoundPref",
            targets: ["SoundPref"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SoundPref",
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
            name: "SoundPrefTests",
            dependencies: ["SoundPref"],
            path: "Tests"
        )
    ]
)
