// User story: when I dictate a long text, the bar grows downwards with the text so I can read
// everything I've said. Its top edge stays put. It is 720 px wide, never taller than half of the
// screen; once it hits that limit the text scrolls so the newest words stay visible.

import CoreGraphics
import Testing
@testable import WhisperBarCore

@Suite("Bar grows with the text")
struct OverlayGrowthTests {
    @Test("the bar is 720 px wide")
    func width() {
        #expect(OverlayLayout.width == 720)
    }

    @Test("with one line of text the bar keeps its minimum height")
    func minimum() {
        #expect(OverlayLayout.panelHeight(textHeight: 18, maxHeight: 450) == OverlayLayout.minHeight)
    }

    @Test("with several lines the bar is as tall as the text plus padding")
    func grows() {
        #expect(OverlayLayout.panelHeight(textHeight: 300, maxHeight: 450) == 300 + OverlayLayout.verticalPadding)
    }

    @Test("the bar never grows beyond the maximum height")
    func capped() {
        #expect(OverlayLayout.panelHeight(textHeight: 5000, maxHeight: 450) == 450)
    }

    @Test("the maximum height is half of the visible screen")
    func maxIsHalfScreen() {
        #expect(OverlayLayout.maxHeight(visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)) == 450)
    }

    @Test("when the bar grows, its top edge stays in the same place")
    func topAnchored() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let small = OverlayLayout.frame(visibleFrame: visible, size: CGSize(width: 720, height: 64), topMargin: 10)
        let tall = OverlayLayout.frame(visibleFrame: visible, size: CGSize(width: 720, height: 400), topMargin: 10)
        #expect(small.maxY == tall.maxY)
        #expect(tall.minY < small.minY)
    }
}
