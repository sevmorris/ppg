// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasswordGen",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PasswordGen",
            path: "Sources/PasswordGen"
        )
    ]
)
