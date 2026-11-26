import Foundation

public enum MediaCommand: Equatable, Sendable { case pause, play }

/// Pause what's playing when dictation starts; resume only what we paused.
public struct MediaPauseCoordinator: Sendable {
    private var pausedByUs = false

    public init() {}

    public mutating func recordingStarted(isPlaying: Bool) -> MediaCommand? {
        pausedByUs = isPlaying
        return isPlaying ? .pause : nil
    }

    public mutating func recordingEnded(isPlaying: Bool) -> MediaCommand? {
        defer { pausedByUs = false }
        return pausedByUs && !isPlaying ? .play : nil
    }
}

/// Parses `mediaremote-adapter get` output (JSON object, or `null` when nothing is playing).
public enum NowPlayingParser {
    public static func isPlaying(_ json: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: json, options: [.fragmentsAllowed]),
              let dict = object as? [String: Any]
        else { return false }
        return (dict["playing"] as? Bool) ?? false
    }
}
