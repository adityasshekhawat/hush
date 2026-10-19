import Foundation
import Testing
@testable import HushCore

@Suite struct AskEval {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../evals/asks.json").standardized

    @Test func everyEvalAskTakesItsExpectedLane() throws {
        let set = try AskEvalSet.load(Self.url)
        #expect(set.cases.count >= 30)
        // With browser tasks off, nothing routes there.
        for c in set.cases where c.lane == "do" {
            var ctx = set.context(for: c)
            ctx.browserTasks = false
            #expect(AskRouter.route(c.ask, context: ctx).lane != .browser)
        }
        for c in set.cases {
            #expect(DoIntent.matches(c.ask) == (c.lane == "do"), "DoIntent wrong for \"\(c.ask)\"")
            let lane = AskEvalSet.laneName(AskRouter.route(c.ask, context: set.context(for: c)).lane)
            #expect(lane == c.lane, "\"\(c.ask)\" went to \(lane), expected \(c.lane)")
        }
    }

    @Test func gradingChecksShapeAndText() {
        let c = AskEvalSet.Case(ask: "q", app: nil, lane: "quick", shape: .formula, contains: ["xlookup("])
        let good = AnswerShape(shape: .formula, title: "XLOOKUP", primary: "=XLOOKUP(A2, B:B, C:C)")
        #expect(AskEvalSet.grade(good, against: c).isEmpty)
        let bad = AnswerShape(shape: .prose, title: "Lookup", primary: "Use VLOOKUP")
        #expect(AskEvalSet.grade(bad, against: c).count == 2)
        #expect(AskEvalSet.grade(nil, against: c) == ["no structured answer"])
    }
}
