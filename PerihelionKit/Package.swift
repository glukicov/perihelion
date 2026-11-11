// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PerihelionKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PerihelionCore", targets: ["PerihelionCore"]),
        .library(name: "PerihelionAudio", targets: ["PerihelionAudio"]),
    ],
    targets: [
        .target(name: "PerihelionCore"),
        .target(name: "PerihelionAudio", dependencies: ["PerihelionCore"]),
        .testTarget(
            name: "PerihelionCoreTests",
            dependencies: ["PerihelionCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "PerihelionAudioTests", dependencies: ["PerihelionAudio"]),
    ]
)
