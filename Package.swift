// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoShift",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GeoShift",
            targets: ["GeoShift"]
        )
    ],
    targets: [
        .target(
            name: "GeoShift",
            path: "Sources",
            exclude: [
                "App/GeoShiftApp.swift"
            ]
        ),
        .testTarget(
            name: "GeoShiftTests",
            dependencies: ["GeoShift"],
            path: "Tests/GeoShiftTests"
        )
    ]
)
