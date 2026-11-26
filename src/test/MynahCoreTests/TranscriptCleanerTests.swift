// User story: after I stop dictating, the recognised text is pasted into the app I'm in.
// The text must be tidy (no stray leading/trailing whitespace or double spaces),
// and if nothing was recognised, nothing is pasted at all.

import Testing
@testable import MynahCore

@Suite("Transcript cleanup before paste")
struct TranscriptCleanerTests {
    @Test("leading and trailing whitespace is removed")
    func trims() {
        #expect(TranscriptCleaner.clean("  Привет, мир.  \n") == "Привет, мир.")
    }

    @Test("runs of whitespace inside the text collapse to a single space")
    func collapsesWhitespace() {
        #expect(TranscriptCleaner.clean("one   two\n\tthree") == "one two three")
    }

    @Test("an empty or whitespace-only transcript yields nothing to paste")
    func emptyIsNil() {
        #expect(TranscriptCleaner.clean("") == nil)
        #expect(TranscriptCleaner.clean("   \n ") == nil)
    }

    @Test("unknown-token markers from the model are dropped")
    func dropsUnk() {
        #expect(TranscriptCleaner.clean("he said <unk>hi<unk>") == "he said hi")
        #expect(TranscriptCleaner.clean("<unk>") == nil)
    }
}
