// User story: if I hit the hotkey by accident and release it straight away,
// the app should not run recognition or paste garbage — very short recordings are discarded.

import Testing
@testable import MynahCore

@Suite("Recording policy: discard accidental micro-recordings")
struct RecordingPolicyTests {
    @Test("a recording shorter than the minimum duration is not transcribed")
    func tooShort() {
        let p = RecordingPolicy(minimumDuration: 0.3)
        #expect(!p.shouldTranscribe(sampleCount: 16_000 / 10, sampleRate: 16_000))
    }

    @Test("a recording at or above the minimum duration is transcribed")
    func longEnough() {
        let p = RecordingPolicy(minimumDuration: 0.3)
        #expect(p.shouldTranscribe(sampleCount: 4_800, sampleRate: 16_000))
        #expect(p.shouldTranscribe(sampleCount: 160_000, sampleRate: 16_000))
    }

    @Test("duration is computed from sample count and sample rate")
    func duration() {
        #expect(RecordingPolicy.duration(sampleCount: 32_000, sampleRate: 16_000) == 2.0)
    }
}
