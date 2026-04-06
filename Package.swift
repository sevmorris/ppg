// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PasswordGen",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PasswordGen",
            path: "Sources/PasswordGen"
        ),
        .testTarget(
            name: "PasswordGenTests",
            dependencies: ["PasswordGen"],
            path: "Tests/PasswordGenTests",
            // Define TESTING so PasswordGenApp.swift can suppress @main in test builds,
            // preventing a conflict with the XCTest runner's own entry point.
            swiftSettings: [.define("TESTING")]
        ),
    ]
)
