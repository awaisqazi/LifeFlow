// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LifeFlowCore",
    platforms: [
        .iOS("26.1"),
        .watchOS("26.2")
    ],
    products: [
        .library(
            name: "LifeFlowCore",
            targets: ["LifeFlowCore"]
        )
    ],
    targets: [
        .target(
            name: "LifeFlowCore"
        ),
        .testTarget(
            name: "LifeFlowCoreTests",
            dependencies: ["LifeFlowCore"]
        )
    ]
)
