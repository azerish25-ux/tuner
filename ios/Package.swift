// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TimbreCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TimbreCore", targets: ["TimbreCore"])],
    targets: [
        .target(name: "TimbreCore", resources: [.process("Resources")]),
        .testTarget(name: "TimbreCoreTests", dependencies: ["TimbreCore"])
    ]
)
