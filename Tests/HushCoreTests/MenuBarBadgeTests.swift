import Testing
@testable import HushCore

@Suite struct MenuBarBadges {
    @Test func idleIsOutlineWithNoCount() {
        #expect(MenuBarBadge(waiting: 0, showCount: true) == MenuBarBadge(waiting: 0, showCount: false))
        #expect(!MenuBarBadge(waiting: 0, showCount: true).holding)
        #expect(MenuBarBadge(waiting: 0, showCount: true).count == nil)
    }

    @Test func countOnlyWhenAskedFor() {
        #expect(MenuBarBadge(waiting: 2, showCount: false).holding)
        #expect(MenuBarBadge(waiting: 2, showCount: false).count == nil)
        #expect(MenuBarBadge(waiting: 2, showCount: true).count == "2")
    }

    /// Keeps the item narrow so the bar doesn't shift as mail piles up.
    @Test func capsAtNinePlus() {
        #expect(MenuBarBadge(waiting: 9, showCount: true).count == "9")
        #expect(MenuBarBadge(waiting: 12, showCount: true).count == "9+")
    }
}

@Suite struct MenuBarGlyphs {
    @Test func glyphFollowsWhatMatters() {
        #expect(MenuBarBadge(waiting: 0, showCount: false).glyph == .idle)
        #expect(MenuBarBadge(waiting: 2, showCount: false).glyph == .mail)
        #expect(MenuBarBadge(waiting: 1, showCount: false, meetingWaiting: true).glyph == .meeting)
        #expect(MenuBarBadge(waiting: 0, showCount: false, focused: true).glyph == .focus)
        #expect(MenuBarBadge(waiting: 0, showCount: false, asleep: true).glyph == .sleep)
        #expect(MenuBarBadge(waiting: 1, showCount: false, focused: true).glyph == .mail)
    }
}
