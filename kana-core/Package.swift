// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KanaCore",
    products: [
        .library(name: "KanaCore", targets: ["KanaCore"])
    ],
    targets: [
        .target(name: "KanaCore", resources: [.copy("Resources/Packs")]),
        .testTarget(name: "KanaCoreTests", dependencies: ["KanaCore"])
    ]
)
