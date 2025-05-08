// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SwiftyGradient",
    products: [
        .library(name: "SwiftyGradient", targets: ["SwiftyGradient"]),
    ],
    targets: [
        .target(
            name: "SwiftyGradient",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
