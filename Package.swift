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
            dependencies: [],
            resources: [
                .process("Resources/IncitoWebview")
            ]
        ),
        .testTarget(
            name: "IncitoTests",
            dependencies: ["Incito"]
        )
    ]
)
