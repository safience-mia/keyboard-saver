// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "keyboard_guard",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "keyboard-guard", targets: ["keyboard_guard"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "keyboard_guard",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [.process("PrivacyInfo.xcprivacy")]
        )
    ]
)
