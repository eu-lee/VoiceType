// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceType",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceType", targets: ["VoiceType"])
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.9.4")
    ],
    targets: [
        .executableTarget(
            name: "VoiceType",
            dependencies: [
                "SwiftWhisper",
                "KeyboardShortcuts"
            ],
            path: "VoiceType",
            exclude: ["Info.plist"]
        )
    ]
)
