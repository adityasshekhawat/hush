import Foundation
import Testing
@testable import HushCore

@Suite struct FollowUps {
    @Test func promptCarriesEarlierTurnsThenTheQuestion() {
        let f = FollowUp(turns: [.init(question: "XLOOKUP in sheets?", answer: "=XLOOKUP(A2, B:B, C:C)")], lane: .quick)
        let p = f.prompt("and if nothing matches?")
        #expect(p.contains("Q: XLOOKUP in sheets?"))
        #expect(p.contains("A: =XLOOKUP(A2, B:B, C:C)"))
        #expect(p.hasSuffix("Follow-up: and if nothing matches?"))
    }

    @Test func keepsOnlyTheLastFewTurnsAndCapsLongAnswers() {
        var f = FollowUp(turns: [], lane: .quick)
        for i in 1...5 { f = f.adding(.init(question: "q\(i)", answer: String(repeating: "x", count: 4000))) }
        #expect(f.turns.map(\.question) == ["q3", "q4", "q5"])
        #expect(f.isFull)
        #expect(f.prompt("next").count < 3 * 1600 + 200)
    }
}
