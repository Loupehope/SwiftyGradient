// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftyGradient",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "SwiftyGradient", targets: ["SwiftyGradient"]),
    ],
    targets: [
        .target(
            name: "SwiftyGradient",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
                .copy("SwiftyGradientShader.metal")
            ]
        ),
    ]
)
