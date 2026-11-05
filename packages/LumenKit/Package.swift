// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumenKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "LumenDomain", targets: ["LumenDomain"]),
        .library(name: "LumenApplication", targets: ["LumenApplication"]),
        .library(name: "LumenSignal", targets: ["LumenSignal"]),
        .library(name: "LumenProtocol", targets: ["LumenProtocol"]),
        .library(name: "LumenTransport", targets: ["LumenTransport"]),
        .library(name: "LumenProximity", targets: ["LumenProximity"]),
        .library(name: "LumenMacUI", targets: ["LumenMacUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.39.0"),
    ],
    targets: [
        .target(name: "LumenDomain"),
        .target(name: "LumenApplication", dependencies: ["LumenDomain"]),
        .target(name: "LumenSignal"),
        .target(
            name: "LumenProtocol",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")]
        ),
        .target(
            name: "LumenTransport",
            dependencies: ["LumenApplication", "LumenDomain", "LumenProtocol"]
        ),
        .target(name: "LumenProximity"),
        .target(
            name: "LumenMacUI",
            dependencies: ["LumenApplication", "LumenDomain"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "LumenDomainTests", dependencies: ["LumenDomain"]),
        .testTarget(name: "LumenApplicationTests", dependencies: ["LumenApplication", "LumenDomain"]),
        .testTarget(name: "LumenProtocolTests", dependencies: ["LumenProtocol"]),
    ]
)
