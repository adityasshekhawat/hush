import Foundation
import Testing
@testable import HushCore

@Suite struct Routing {
    let hush = "/Users/x/Developer/hush"
    var ctx: AskContext { AskContext(frontmostApp: "ai.perplexity.comet", repos: [hush, "/Users/x/Developer/notes-api"], defaultRepo: hush) }

    @Test func spreadsheetQuestionIsQuickEvenWithARepo() {
        let r = AskRouter.route("What's the formula of XLOOKUP in gsheet", context: ctx)
        #expect(r.lane == .quick)
        #expect(!r.explicit)
    }

    @Test func explicitPrefixesWin() {
        let r = AskRouter.route("@gpt What's the formula of XLOOKUP in gsheet", context: ctx)
        #expect(r.lane == .handoff(.chatgpt))
        #expect(r.text == "What's the formula of XLOOKUP in gsheet")
        #expect(r.explicit)
        #expect(AskRouter.route("@claude hi", context: ctx).lane == .handoff(.claude))
        #expect(AskRouter.route("@pplx news", context: ctx).lane == .handoff(.perplexity))
        #expect(AskRouter.route("@notes-api what's the stack?", context: ctx).lane == .repo(path: "/Users/x/Developer/notes-api"))
        #expect(AskRouter.route("@quick where is the cap", context: ctx).lane == .quick)
    }

    @Test func codeQuestionsGoToTheRepo() {
        #expect(AskRouter.route("Where is the daily interrupt cap defined?", context: ctx).lane == .repo(path: hush))
        #expect(AskRouter.route("what does notes-api use for auth", context: ctx).lane == .repo(path: "/Users/x/Developer/notes-api"))
        let noRepo = AskContext(repos: [], defaultRepo: nil)
        #expect(AskRouter.route("Where is the daily interrupt cap defined?", context: noRepo).lane == .quick)
    }

    @Test func openEndedOrLongGoesToTheAssistant() {
        #expect(AskRouter.route("Help me plan a 3-day trip to Goa", context: ctx).lane == .handoff(.chatgpt))
        let long = Array(repeating: "word", count: 45).joined(separator: " ")
        #expect(AskRouter.route(long, context: ctx).lane == .handoff(.chatgpt))
        var c = ctx; c.preferredHandoff = .claude
        #expect(AskRouter.route("brainstorm names for a cat", context: c).lane == .handoff(.claude))
    }

    @Test func generalHowTosStayQuickEvenWithARepo() {
        #expect(AskRouter.route("git: undo my last commit but keep the changes", context: ctx).lane == .repo(path: hush)) // "my last commit"
        #expect(AskRouter.route("how do I undo a git commit but keep changes", context: ctx).lane == .quick)
        #expect(AskRouter.route("how do I undo a git commit but keep the changes", context: ctx).lane == .quick)
        #expect(AskRouter.route("what's the difference between a mutex and a semaphore", context: ctx).lane == .quick)
        #expect(AskRouter.route("what is a pure function", context: ctx).lane == .quick)
        #expect(AskRouter.route("why does this function return nil", context: ctx).lane == .repo(path: hush))
        #expect(AskRouter.route("summarise the README", context: ctx).lane == .repo(path: hush))
        #expect(AskRouter.route("What changed in the last 3 commits?", context: ctx).lane == .repo(path: hush))
        #expect(AskRouter.route("which branches changed today", context: ctx).lane == .repo(path: hush))
    }

    @Test func plainQuestionsAreQuick() {
        #expect(AskRouter.route("how many ml in a cup", context: ctx).lane == .quick)
        #expect(AskRouter.route("git undo last commit keep changes", context: AskContext()).lane == .quick)
    }

    @Test func tabCycles() {
        let a = AskRouter.next(after: .quick, context: ctx)
        #expect(a == .repo(path: hush))
        let s = AskRouter.next(after: a, context: ctx)
        #expect(s == .sessions)
        let b = AskRouter.next(after: s, context: ctx)
        #expect(b == .handoff(.chatgpt))
        var lane = b
        for _ in 0..<2 { lane = AskRouter.next(after: lane, context: ctx) }
        #expect(AskRouter.next(after: lane, context: ctx) == .quick)
    }

    @Test func handoffURLsAreEncoded() {
        let u = AskLane.Provider.chatgpt.url(for: "XLOOKUP & VLOOKUP?", appInstalled: false)!
        #expect(u.absoluteString == "https://chatgpt.com/?q=XLOOKUP%20%26%20VLOOKUP%3F")
        #expect(AskLane.Provider.claude.url(for: "hi", appInstalled: true)!.absoluteString == "claude://claude.ai/new?q=hi")
        #expect(AskLane.Provider.claude.url(for: "hi", appInstalled: false)!.scheme == "https")
    }

    @Test func shapesDecodeLeniently() throws {
        let json = #"{"shape":"formula","title":"XLOOKUP","primary":"=XLOOKUP(a,b,c)","parts":[{"label":"a","detail":"key"}],"app":"Google Sheets"}"#
        let s = try JSONDecoder().decode(AnswerShape.self, from: Data(json.utf8))
        #expect(s.shape == .formula && s.parts.count == 1 && s.app == "Google Sheets" && !s.destructive)
        let weird = try JSONDecoder().decode(AnswerShape.self, from: Data(#"{"shape":"poem","primary":"x"}"#.utf8))
        #expect(weird.shape == .prose)
        #expect(s.plainText.contains("• a: key"))
    }
}
