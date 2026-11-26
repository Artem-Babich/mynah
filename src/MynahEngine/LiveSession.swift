import AVFoundation
import FluidAudio
import Foundation
import MynahCore

/// Creates live (streaming) sessions on top of already-loaded models.
public struct LiveSessionFactory: Sendable {
    let models: AsrModels
    /// Window layout in seconds. FluidAudio's default (2+11+2) only emits text after 13 s of
    /// audio — useless for dictation. A short centre chunk gives an update every `chunk` s
    /// with ~`chunk + right` s latency; `left` keeps context for accuracy.
    public var chunk: TimeInterval = 1.0
    public var left: TimeInterval = 4.0
    public var right: TimeInterval = 0.5

    /// Starts immediately: audio fed before the stream is ready is buffered, not lost.
    public func start(onText: @escaping @Sendable (String) -> Void) -> LiveSession {
        let config = SlidingWindowAsrConfig(
            chunkSeconds: chunk,
            hypothesisChunkSeconds: chunk,
            leftContextSeconds: left,
            rightContextSeconds: right,
            minContextForConfirmation: left,
            confirmationThreshold: 0.80)
        return LiveSession(models: models, config: config, onText: onText)
    }
}

/// One dictation's live preview via FluidAudio's sliding-window ASR (Parakeet v3).
/// Display only — the pasted text comes from the full batch pass.
public final class LiveSession: @unchecked Sendable {
    private let continuation: AsyncStream<AVAudioPCMBuffer>.Continuation
    private var worker: Task<Void, Never>?
    private let lock = NSLock()
    private var manager: SlidingWindowAsrManager?

    init(models: AsrModels, config: SlidingWindowAsrConfig, onText: @escaping @Sendable (String) -> Void) {
        let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation
        worker = Task { [weak self] in
            do {
                let mgr = SlidingWindowAsrManager(config: config)
                try await mgr.loadModels(models)
                let updates = await mgr.transcriptionUpdates  // subscribe before feeding
                try await mgr.startStreaming(source: .microphone)
                self?.setManager(mgr)

                let listener = Task {
                    for await _ in updates {
                        let text = LiveTranscript.compose(
                            confirmed: await mgr.confirmedTranscript,
                            volatile: await mgr.volatileTranscript)
                        onText(text)
                    }
                }
                for await buffer in stream {
                    if Task.isCancelled { break }
                    await mgr.streamAudio(buffer)
                }
                listener.cancel()
            } catch {
                FileHandle.standardError.write(Data("live session error: \(error)\n".utf8))
            }
        }
    }

    /// Thread-safe; call from the audio tap. Buffers stay ordered.
    public func feed(_ buffer: AVAudioPCMBuffer) {
        continuation.yield(buffer)
    }

    public func stop() async {
        continuation.finish()
        worker?.cancel()
        if let mgr = lock.withLock({ manager }) { await mgr.cancel() }
    }

    private func setManager(_ mgr: SlidingWindowAsrManager) {
        lock.withLock { manager = mgr }
    }
}
