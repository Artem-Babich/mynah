// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhisperBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WhisperBar", targets: ["WhisperBar"]),
        .executable(name: "whisperbar-cli", targets: ["WhisperBarCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.18.4"),
    ],
    targets: [
        // Pure logic, no audio/UI/model dependencies — fully unit-tested.
        .target(
            name: "WhisperBarCore",
            path: "src/WhisperBarCore"
        ),
        // Thin wrapper over FluidAudio Parakeet TDT v3 (shared by app and CLI).
        .target(
            name: "WhisperBarEngine",
            dependencies: [
                "WhisperBarCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "src/WhisperBarEngine"
        ),
        // Menu-bar app: hotkey, recording, transcription, paste.
        .executableTarget(
            name: "WhisperBar",
            dependencies: ["WhisperBarCore", "WhisperBarEngine"],
            path: "src/WhisperBar"
        ),
        // CLI: download the model and transcribe a file (smoke test without UI).
        .executableTarget(
            name: "WhisperBarCLI",
            dependencies: ["WhisperBarCore", "WhisperBarEngine"],
            path: "src/WhisperBarCLI"
        ),
        .testTarget(
            name: "WhisperBarCoreTests",
            dependencies: ["WhisperBarCore"],
            path: "src/test/WhisperBarCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
