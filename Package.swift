// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mynah",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mynah", targets: ["Mynah"]),
        .executable(name: "mynah-cli", targets: ["MynahCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.18.4"),
    ],
    targets: [
        // Pure logic, no audio/UI/model dependencies — fully unit-tested.
        .target(
            name: "MynahCore",
            path: "src/MynahCore"
        ),
        // Thin wrapper over FluidAudio Parakeet TDT v3 (shared by app and CLI).
        .target(
            name: "MynahEngine",
            dependencies: [
                "MynahCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "src/MynahEngine"
        ),
        // Menu-bar app: hotkey, recording, transcription, paste.
        .executableTarget(
            name: "Mynah",
            dependencies: ["MynahCore", "MynahEngine"],
            path: "src/Mynah"
        ),
        // CLI: download the model and transcribe a file (smoke test without UI).
        .executableTarget(
            name: "MynahCLI",
            dependencies: ["MynahCore", "MynahEngine"],
            path: "src/MynahCLI"
        ),
        .testTarget(
            name: "MynahCoreTests",
            dependencies: ["MynahCore"],
            path: "src/test/MynahCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
