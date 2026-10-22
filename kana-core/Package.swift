// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KanaCore",
    products: [
        .library(name: "KanaCore", targets: ["KanaCore"])
    ],
    targets: [
        .target(name: "KanaCore"),
        .testTarget(name: "KanaCoreTests", dependencies: ["KanaCore"])
    ]
)
