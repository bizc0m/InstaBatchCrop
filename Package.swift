// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InstaBatchCrop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "InstaBatchCropCore", targets: ["InstaBatchCropCore"]),
        .executable(name: "InstaBatchCrop", targets: ["InstaBatchCrop"])
    ],
    targets: [
        .target(name: "InstaBatchCropCore", path: "InstaBatchCropCore"),
        .executableTarget(
            name: "InstaBatchCrop",
            dependencies: ["InstaBatchCropCore"],
            path: "InstaBatchCrop",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "InstaBatchCropTests",
            dependencies: ["InstaBatchCropCore"],
            path: "InstaBatchCropTests"
        )
    ]
)
