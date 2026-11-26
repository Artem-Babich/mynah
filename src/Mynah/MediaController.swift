import Foundation
import MynahCore

/// Pauses/resumes the system "Now Playing" app around a dictation.
/// macOS 15.4+ blocks MediaRemote for third-party apps, so we go through the bundled
/// mediaremote-adapter (vendor/, BSD-3), which runs via Apple's /usr/bin/perl.
/// All work happens on one serial queue, so start/end are applied in order and never block the UI.
final class MediaController {
    private let queue = DispatchQueue(label: "mynah.media")
    private var coordinator = MediaPauseCoordinator()
    private let script: URL?
    private let framework: URL?

    init(resources: URL? = Bundle.main.resourceURL?.appendingPathComponent("MediaRemote")) {
        let script = resources?.appendingPathComponent("mediaremote-adapter.pl")
        let framework = resources?.appendingPathComponent("MediaRemoteAdapter.framework")
        let ok = [script, framework].allSatisfy { $0.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
        self.script = ok ? script : nil
        self.framework = ok ? framework : nil
        if !ok { Log.info("media: adapter not bundled — pause/resume disabled") }
    }

    func recordingStarted() {
        guard script != nil else { return }
        queue.async { [self] in
            let playing = isPlaying()
            let command = coordinator.recordingStarted(isPlaying: playing)
            Log.info("media: start playing=\(playing) → \(command.map { "\($0)" } ?? "none")")
            if let command { send(command) }
        }
    }

    func recordingEnded() {
        guard script != nil else { return }
        queue.async { [self] in
            let playing = isPlaying()
            let command = coordinator.recordingEnded(isPlaying: playing)
            Log.info("media: end playing=\(playing) → \(command.map { "\($0)" } ?? "none")")
            if let command { send(command) }
        }
    }

    private func isPlaying() -> Bool {
        run(["get"]).map(NowPlayingParser.isPlaying) ?? false
    }

    private func send(_ command: MediaCommand) {
        // MediaRemote command ids: kMRPlay = 0, kMRPause = 1.
        _ = run(["send", command == .play ? "0" : "1"])
    }

    /// Runs the adapter with a hard timeout so a hung helper never wedges the queue.
    private func run(_ arguments: [String], timeout: TimeInterval = 2) -> Data? {
        guard let script, let framework else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, framework.path] + arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        do {
            try process.run()
        } catch {
            Log.info("media: adapter failed to start: \(error)")
            return nil
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            Log.info("media: adapter timed out (\(arguments.joined(separator: " ")))")
            return nil
        }
        return stdout.fileHandleForReading.readDataToEndOfFile()
    }
}
