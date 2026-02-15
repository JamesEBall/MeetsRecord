// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeetsRecord",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "MeetsRecord",
            dependencies: ["SwiftWhisper"],
            path: "MeetsRecord",
            exclude: [
                "App/Info.plist",
                "App/MeetsRecord.entitlements"
            ],
            resources: [
                .copy("Resources/ggml-base.en.bin")
            ]
        )
    ]
)
