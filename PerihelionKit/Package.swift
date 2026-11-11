// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PerihelionKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PerihelionCore", targets: ["PerihelionCore"])
    ],
    targets: [
        .target(name: "PerihelionCore"),
        .testTarget(
            name: "PerihelionCoreTests",
            dependencies: ["PerihelionCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
