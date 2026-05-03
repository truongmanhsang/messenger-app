// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MessengerNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MessengerNative", targets: ["MessengerNative"])
    ],
    targets: [
        .executableTarget(
            name: "MessengerNative",
            resources: [
                .copy("Resources/custom.css")
            ]
        )
    ]
)
