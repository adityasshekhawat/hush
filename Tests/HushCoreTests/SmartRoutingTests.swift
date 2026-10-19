import Foundation
import Testing
@testable import HushCore

@Suite struct SmartRouting {
    let ctx = AskContext(repos: ["/x/hush"], defaultRepo: "/x/hush")

    @Test func onlyTheFallbackIsUnsure() {
        #expect(AskRouter.route("what's the capital of chile", context: ctx).confident)            // quick-shaped
        #expect(AskRouter.route("formula for XLOOKUP", context: ctx).confident)
        #expect(!AskRouter.route("which ones are still open", context: ctx).confident)
        #expect(AskRouter.route("what all claude sessions are running", context: ctx).confident)   // a rule matched
    }

    @Test func learnsFromCorrections() {
        var l = LearnedRoutes()
        l.record("which ones are still open", lane: .sessions)
        #expect(l.lookup("which ones are still open?") == .sessions)
        #expect(l.lookup("which tabs are open in chrome") == nil)
        l.record("which ones are still open", lane: .quick)          // a newer correction replaces it
        #expect(l.lookup("which ones are still open") == .quick)
        #expect(l.entries.count == 1)
    }

    @Test func parsesTheModelsPick() {
        let ok = RouteCheck.parse(Data(#"{"lane":"repo","why":"about hush code"}"#.utf8), question: "where is the cap", context: ctx)
        #expect(ok?.lane == .repo(path: "/x/hush"))
        #expect(RouteCheck.parse(Data(#"{"lane":"browser","why":"x"}"#.utf8), question: "q", context: ctx) == nil)   // browser off
        #expect(RouteCheck.parse(Data(#"{"lane":"nonsense"}"#.utf8), question: "q", context: ctx) == nil)
        #expect(RouteCheck.jsonSchema(context: ctx).contains(#""enum":["quick","repo","handoff","sessions"]"#))
        #expect(RouteCheck.systemPrompt(context: ctx, runningSessions: 2).contains("repo: a question about the code in one of the user's repositories (hush)"))
    }
}
