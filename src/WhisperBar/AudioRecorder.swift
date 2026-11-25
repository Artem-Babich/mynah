import AVFoundation
import Foundation

/// Captures the default microphone and converts on the fly to 16 kHz mono Float32.
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private let target = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private(set) var isRunning = false

    /// Called on the audio thread with each converted 16 kHz chunk (for live preview + level meter).
    /// Set before `start()`; cleared by `stop()`.
    var onChunk: ((AVAudioPCMBuffer, UnsafeBufferPointer<Float>) -> Void)?

    func start() throws {
        lock.withLock { samples.removeAll(keepingCapacity: true) }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noInput }
        guard let converter = AVAudioConverter(from: format, to: target) else {
            throw RecorderError.converter
        }
        self.converter = converter
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        isRunning = true
    }

    /// Stops capture and returns everything recorded since `start()`.
    func stop() -> [Float] {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
        converter = nil
        onChunk = nil
        return lock.withLock {
            let out = samples
            samples = []
            return out
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData, out.frameLength > 0 else { return }
        let chunk = UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength))
        lock.withLock { samples.append(contentsOf: chunk) }
        onChunk?(out, chunk)
    }

    enum RecorderError: Error, LocalizedError {
        case noInput, converter
        var errorDescription: String? {
            switch self {
            case .noInput: return "Нет доступного микрофона"
            case .converter: return "Не удалось настроить конвертацию аудио"
            }
        }
    }
}
