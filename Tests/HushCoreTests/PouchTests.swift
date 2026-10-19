import Foundation
import Testing
@testable import HushCore

@Suite struct PouchRules {
    @Test func checksWhatsOnTheClipboard() {
        #expect(Pouch.check(nil) == .empty)
        #expect(Pouch.check("  \n ") == .empty)
        #expect(Pouch.check("  Hello there \n") == .ok("Hello there"))
        let long = String(repeating: "a", count: Pouch.maxCharacters + 1)
        #expect(Pouch.check(long) == .tooLong(Pouch.maxCharacters + 1))
    }

    @Test func leavesCodeAlone() {
        #expect(Pouch.check("func retry(times: Int) {\n    for _ in 0..<times {\n        try op()\n    }\n}") == .code)
        #expect(Pouch.check("def total(xs):\n    return sum(xs)") == .code)
        #expect(Pouch.check("const x = 1;\nconsole.log(x);") == .code)
        // Prose with a stray brace or a single line isn't code.
        #expect(Pouch.check("Lunch at 1? {smiles}") == .ok("Lunch at 1? {smiles}"))
        #expect(Pouch.check("Hi team,\nThe deploy is done.\nThanks!") == .ok("Hi team,\nThe deploy is done.\nThanks!"))
    }

    @Test func promptCarriesTheVerbAndTheText() {
        let p = Pouch.prompt("We should ship on Friday.", verb: .shorter)
        #expect(p.hasPrefix("Cut it to about half the words."))
        #expect(p.hasSuffix("Text:\nWe should ship on Friday."))
        #expect(PouchVerb.allCases.map(\.title) == ["Simpler", "Shorter", "Bullets"])
    }

    @Test func cleansAnswersForPasting() {
        let o = "The original text."
        #expect(Pouch.clean("  \"Short and sweet.\"  ", verb: .shorter, original: o) == "Short and sweet.")
        #expect(Pouch.clean("```\nfixed\n```", verb: .simpler, original: o) == "fixed")
        #expect(Pouch.clean("```text\nfixed\n```", verb: .simpler, original: o) == "fixed")
        // Quotes inside the answer are left alone.
        #expect(Pouch.clean("\"a\" and \"b\"", verb: .simpler, original: o) == "\"a\" and \"b\"")
        #expect(Pouch.clean("• one\n* two\n-three\n\n- four", verb: .bullets, original: o) == "- One\n- Two\n- Three\n- Four")
        #expect(Pouch.clean("   ", verb: .simpler, original: o) == nil)
        #expect(Pouch.clean(" The original text. ", verb: .simpler, original: o) == nil)
    }

    @Test func handoffKeepsTheAsk() {
        #expect(Pouch.handoffQuestion("hi", verb: .bullets).hasSuffix("\n\nhi"))
    }
}
