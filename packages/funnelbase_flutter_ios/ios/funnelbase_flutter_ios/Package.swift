// swift-tools-version: 5.9

import Foundation
import PackageDescription

// The iOS implementation of funnelbase_flutter, over the native iOS SDK: the funnelbase-ios Swift
// package, fetched from its repository by version.
//
// FUNNELBASE_IOS_PATH, when set, points at a checkout of funnelbase-ios to build against instead —
// how a version is tried before its tag exists, and how someone works on both repositories at
// once. Read when the manifest is evaluated, so set it in the shell that runs `flutter build`.
let localSdk = ProcessInfo.processInfo.environment["FUNNELBASE_IOS_PATH"].flatMap { $0.isEmpty ? nil : $0 }

let sdk: Package.Dependency = localSdk.map { .package(path: $0) }
    ?? .package(url: "https://github.com/Funnelbase/funnelbase-ios.git", from: "0.2.0")

let package = Package(
    name: "funnelbase_flutter_ios",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "funnelbase-flutter-ios", targets: ["funnelbase_flutter_ios"]),
    ],
    dependencies: [
        sdk,
    ],
    targets: [
        .target(
            name: "funnelbase_flutter_ios",
            dependencies: [
                .product(name: "Funnelbase", package: "funnelbase-ios"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
