// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeetingRecorder",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "MeetingRecorder",
            dependencies: ["SwiftWhisper"],
            path: "MeetingRecorder",
            exclude: [
                "App/Info.plist",
                "App/MeetingRecorder.entitlements"
            ],
            resources: [
                .copy("Resources/ggml-base.en.bin")
            ]
        )
    ]
)
