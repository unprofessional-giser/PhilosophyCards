// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhilosophyCards",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PhilosophyCards", targets: ["PhilosophyCards"])
    ],
    targets: [
        .executableTarget(
            name: "PhilosophyCards",
            path: "Sources/PhilosophyCards",
            resources: [.process("Resources")]
        )
    ]
)
