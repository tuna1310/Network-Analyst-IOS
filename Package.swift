// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetworkAnalyst",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NetworkAnalyst",
            targets: ["NetworkAnalyst"]
        )
    ],
    dependencies: [
        .package(path: "./NetworkCore")
    ],
    targets: [
        .target(
            name: "NetworkAnalyst",
            dependencies: [
                .product(name: "NetworkCore", package: "NetworkCore")
            ],
            path: "NetworkAnalyst",
            exclude: [
                "Resources/Info.plist",
                "Resources/NetworkAnalyst.entitlements"
            ],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
