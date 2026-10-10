// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DisplayMaster",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DisplayMaster", targets: ["DisplayMaster"])
    ],
    targets: [
        .executableTarget(
            name: "DisplayMaster",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
