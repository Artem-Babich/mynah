// User story: I listen to music while working. When I start dictating, whatever is playing
// (Chrome, Spotify, Music…) pauses so it doesn't disturb me or the recognition. As soon as
// I release the hotkey (or press Esc) it resumes — but only if WhisperBar paused it.
// If nothing was playing, nothing starts. If I resumed the player myself during the recording,
// WhisperBar leaves it alone.

import Foundation
import Testing
@testable import WhisperBarCore

@Suite("Pause media while dictating")
struct MediaPauseCoordinatorTests {
    @Test("when music is playing at recording start, it is paused")
    func pausesPlaying() {
        var c = MediaPauseCoordinator()
        #expect(c.recordingStarted(isPlaying: true) == .pause)
    }

    @Test("when nothing is playing at recording start, no command is sent")
    func noPauseWhenSilent() {
        var c = MediaPauseCoordinator()
        #expect(c.recordingStarted(isPlaying: false) == nil)
    }

    @Test("when WhisperBar paused the music, it resumes when the recording ends")
    func resumesWhatItPaused() {
        var c = MediaPauseCoordinator()
        _ = c.recordingStarted(isPlaying: true)
        #expect(c.recordingEnded(isPlaying: false) == .play)
    }

    @Test("when nothing was playing before, nothing is started after the recording")
    func doesNotStartMusic() {
        var c = MediaPauseCoordinator()
        _ = c.recordingStarted(isPlaying: false)
        #expect(c.recordingEnded(isPlaying: false) == nil)
    }

    @Test("when I resumed the player myself during recording, WhisperBar sends nothing")
    func userResumedManually() {
        var c = MediaPauseCoordinator()
        _ = c.recordingStarted(isPlaying: true)
        #expect(c.recordingEnded(isPlaying: true) == nil)
    }

    @Test("resume happens only once per recording")
    func resumeOnce() {
        var c = MediaPauseCoordinator()
        _ = c.recordingStarted(isPlaying: true)
        _ = c.recordingEnded(isPlaying: false)
        #expect(c.recordingEnded(isPlaying: false) == nil)
    }

    @Test("the next recording decides afresh from the current player state")
    func nextRecordingFresh() {
        var c = MediaPauseCoordinator()
        _ = c.recordingStarted(isPlaying: true)
        _ = c.recordingEnded(isPlaying: false)
        _ = c.recordingStarted(isPlaying: false)
        #expect(c.recordingEnded(isPlaying: false) == nil)
    }
}

@Suite("Now Playing state parsing")
struct NowPlayingParserTests {
    @Test("a player reporting playing=true is playing")
    func playing() {
        #expect(NowPlayingParser.isPlaying(Data(#"{"bundleIdentifier":"com.google.Chrome","playing":true}"#.utf8)))
    }

    @Test("a paused player is not playing")
    func paused() {
        #expect(!NowPlayingParser.isPlaying(Data(#"{"bundleIdentifier":"com.spotify.client","playing":false}"#.utf8)))
    }

    @Test("no now-playing app (null) or unreadable output counts as not playing")
    func nothing() {
        #expect(!NowPlayingParser.isPlaying(Data("null".utf8)))
        #expect(!NowPlayingParser.isPlaying(Data()))
        #expect(!NowPlayingParser.isPlaying(Data("garbage".utf8)))
    }
}
