// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Incito",
    platforms: [
        .iOS(.v11),
    ],
    products: [
        .library(
            name: "Incito",
            targets: ["Incito"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Incito",
            dependencies: [],
            path: "Sources"),
    ]
)
