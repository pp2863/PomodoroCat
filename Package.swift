// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PomodoroCat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PomodoroCat",
            path: "Sources/PomodoroCat"
        )
    ]
)
