import AVFoundation
import FluidAudio
import Foundation
import WhisperBarCore

/// Parakeet TDT 0.6b v3 (multilingual, 25 languages incl. Russian) via FluidAudio / CoreML.
public actor ParakeetEngine {
    public static let sampleRate: Double = 16_000

    private var manager: AsrManager?

    public init() {}

    public var isReady: Bool { manager != nil }

    public static var modelDirectory: URL { AsrModels.defaultCacheDirectory(for: .v3) }

    /// Downloads the model on first run (~0.5 GB, cached afterwards) and loads it.
    public func load(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        if manager != nil { return }
        let models = try await AsrModels.downloadAndLoad(
            version: .v3,
            progressHandler: { p in progress?(p.fractionCompleted) }
        )
        let m = AsrManager(config: .default)
        try await m.loadModels(models)
        manager = m
    }

    /// 16 kHz mono float samples → raw transcript.
    public func transcribe(samples: [Float]) async throws -> String {
        guard let manager else { throw EngineError.notLoaded }
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(samples, decoderState: &state).text
    }

    public func transcribe(file url: URL) async throws -> String {
        guard let manager else { throw EngineError.notLoaded }
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(url, decoderState: &state).text
    }

    public enum EngineError: Error, LocalizedError {
        case notLoaded
        public var errorDescription: String? { "Модель ещё не загружена" }
    }
}
