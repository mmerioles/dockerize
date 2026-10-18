// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Dockerize",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Dockerize", targets: ["Dockerize"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.5.0"),
    ],
    targets: [
        // Curriculum, workspaces, and mission checks. No UI, so it is easy to test.
        .target(name: "DockerizeCore"),
        // The SwiftUI app with the embedded bash terminal.
        .executableTarget(
            name: "Dockerize",
            dependencies: ["DockerizeCore", .product(name: "SwiftTerm", package: "SwiftTerm")]
        ),
        .testTarget(name: "DockerizeCoreTests", dependencies: ["DockerizeCore"]),
    ]
)
