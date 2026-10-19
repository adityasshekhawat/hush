import Testing
@testable import HushCore

@Suite struct PasteGuesses {
    func v(_ now: Double, down: Bool = false, up: Double? = 0.05, changed: Bool = false, switched: Double? = nil) -> PasteGuess.Verdict {
        PasteGuess.verdict(shortcutAt: 0, now: now, commandDown: down, commandUpAt: up, clipboardChanged: changed, lastAppSwitch: switched)
    }

    @Test func aQuickCommandVIsAPaste() {
        #expect(v(0.2) == .wait)            // too soon
        #expect(v(0.39) == .wait)           // released at 0.05, settling
        #expect(v(0.45) == .paste)
    }

    @Test func commandTabIsNotAPaste() {
        // ⌘ held while the switcher shows, released at 0.6, the app comes forward at 0.7.
        #expect(v(0.5, down: true, up: nil) == .wait)
        #expect(v(0.8, up: 0.6) == .wait)
        #expect(v(0.8, up: 0.6, switched: 0.7) == .appSwitch)
        // Even a fast ⌘Tab whose activation lands just before the poll.
        #expect(v(0.45, switched: 0.3) == .appSwitch)
    }

    @Test func anOlderAppSwitchDoesntCount() {
        #expect(v(0.45, switched: -3) == .paste)
    }

    @Test func aCopyIsACopy() {
        #expect(v(0.1, down: true, changed: true) == .copy)
        #expect(v(0.5, changed: true, switched: 0.2) == .copy)
    }

    @Test func holdingCommandForAgesIsUnclear() {
        #expect(v(3, down: true, up: nil) == .wait)
        #expect(v(4.5, down: true, up: nil) == .unclear)
    }
}
