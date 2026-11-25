// User story: while I dictate, a bar appears at the top-centre of the screen I'm working on.
// It shows what I'm saying as live text, a microphone level meter and a recording timer,
// so I can see the app is hearing me. Long dictations show the most recent words.
// When I stop, it shows "Распознавание…", then disappears once the text is pasted.

import CoreGraphics
import Testing
@testable import WhisperBarCore

@Suite("Live transcript text in the bar")
struct LiveTranscriptTests {
    @Test("confirmed and volatile parts are joined with a single space")
    func joins() {
        #expect(LiveTranscript.compose(confirmed: "Привет,", volatile: "как дела") == "Привет, как дела")
    }

    @Test("an empty part does not leave stray spaces")
    func emptyParts() {
        #expect(LiveTranscript.compose(confirmed: "", volatile: " hello ") == "hello")
        #expect(LiveTranscript.compose(confirmed: "done.", volatile: "") == "done.")
        #expect(LiveTranscript.compose(confirmed: "", volatile: "") == "")
    }

    @Test("short text is shown in full")
    func shortTail() {
        #expect(LiveTranscript.tail("short text", maxChars: 50) == "short text")
    }

    @Test("long text shows only the latest words, prefixed with an ellipsis and cut on a word boundary")
    func longTail() {
        let text = "one two three four five six seven"
        let tail = LiveTranscript.tail(text, maxChars: 12)
        #expect(tail == "…six seven")
        #expect(tail.count <= 13)
    }
}

@Suite("Microphone level meter")
struct AudioLevelTests {
    @Test("silence shows an empty meter")
    func silence() {
        #expect(AudioLevel.normalized(samples: [Float](repeating: 0, count: 100)) == 0)
        #expect(AudioLevel.normalized(samples: []) == 0)
    }

    @Test("a full-scale signal shows a full meter")
    func fullScale() {
        #expect(AudioLevel.normalized(samples: [Float](repeating: 1, count: 100)) == 1)
    }

    @Test("normal speech volume lands in the middle of the meter, louder is higher")
    func speech() {
        let quiet = AudioLevel.normalized(samples: [Float](repeating: 0.01, count: 100))
        let loud = AudioLevel.normalized(samples: [Float](repeating: 0.1, count: 100))
        #expect(quiet > 0 && quiet < loud && loud < 1)
    }
}

@Suite("Recording timer")
struct ElapsedFormatTests {
    @Test("elapsed time is shown as m:ss")
    func format() {
        #expect(ElapsedFormat.string(0) == "0:00")
        #expect(ElapsedFormat.string(7.9) == "0:07")
        #expect(ElapsedFormat.string(65) == "1:05")
    }
}

@Suite("Bar position")
struct OverlayLayoutTests {
    @Test("the bar is horizontally centred at the top of the visible screen area, below the menu bar")
    func topCentre() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)  // y-up, menu bar excluded
        let frame = OverlayLayout.frame(visibleFrame: visible, size: CGSize(width: 520, height: 72), topMargin: 12)
        #expect(frame == CGRect(x: 460, y: 875 - 12 - 72, width: 520, height: 72))
    }

    @Test("on a secondary screen with an offset origin the bar stays on that screen")
    func secondaryScreen() {
        let visible = CGRect(x: 1440, y: 200, width: 1920, height: 1050)
        let frame = OverlayLayout.frame(visibleFrame: visible, size: CGSize(width: 520, height: 72), topMargin: 12)
        #expect(frame.midX == visible.midX)
        #expect(frame.maxY == visible.maxY - 12)
    }
}
