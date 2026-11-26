import Foundation

public struct RecordingPolicy: Sendable {
    public let minimumDuration: TimeInterval

    public init(minimumDuration: TimeInterval = 0.3) {
        self.minimumDuration = minimumDuration
    }

    public static func duration(sampleCount: Int, sampleRate: Double) -> TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(sampleCount) / sampleRate
    }

    public func shouldTranscribe(sampleCount: Int, sampleRate: Double) -> Bool {
        Self.duration(sampleCount: sampleCount, sampleRate: sampleRate) >= minimumDuration
    }
}
