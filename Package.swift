// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Incito",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        .library(
            name: "Incito",
            targets: ["Incito"]
        ),
    ],
    targets: [
        .target(
            name: "Incito",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "IncitoTests",
            dependencies: [.target(name: "Incito")]
        )
    ]
)
