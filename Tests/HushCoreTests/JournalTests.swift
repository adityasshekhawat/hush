import Foundation
import Testing
@testable import HushCore

@Suite struct JournalEntries {
    func e(_ category: String, _ outcome: Decision.Outcome, _ level: AttentionLevel?, _ reasons: String) -> LoggedDecision {
        LoggedDecision(id: "x", at: tenAM, category: category, finalLevel: level, outcome: outcome, confidence: nil,
                       modelVersion: nil, reasons: reasons, response: nil)
    }

    @Test func readsInPlainWords() {
        let vip = e("mail:boss@work.com", .shown, .gentle, "VIP | daily cap reached → gentle")
        #expect(Journal.source(vip) == "Mail from boss@work.com")
        #expect(Journal.outcome(vip) == "Showed it")
        #expect(Journal.why(vip) == "On your VIP list, today's interrupts were used up")
        let news = e("mail:news@shop.com", .dropped, nil, "bulk headers")
        #expect(Journal.outcome(news) == "Let it go" && Journal.why(news) == "A newsletter or bulk mail")
        let held = e("mail:sam@x.com", .ambient, .ambient, "model: ambient @ 0.85 | quiet hours → ambient")
        #expect(Journal.why(held) == "Could wait, quiet hours")
        let meeting = e("meeting", .shown, .interrupt, "meeting reminder")
        #expect(Journal.source(meeting) == "Calendar" && Journal.outcome(meeting) == "Came out for it")
        #expect(Journal.source(e("agent:hush", .queued, .gentle, "computed in code (agent) | busy → queued")) == "Agent in hush")
        #expect(Journal.why(e("agent:hush", .queued, .gentle, "computed in code (agent) | busy → queued")) == "You were busy")
    }

    @Test func storeKeepsSevenDaysWithTitles() async throws {
        let store = try HushStore(path: ":memory:")
        let engine = DecisionEngine(store: store, classifier: FixedClassifier(level: .gentle, confidence: 0.9))
        _ = try await engine.evaluate(mail("old", subject: "Last month"), now: tenAM.addingTimeInterval(-10 * 86400))
        _ = try await engine.evaluate(mail("new", subject: "Quarterly plan"), now: tenAM)
        let j = try await engine.journal(now: tenAM)
        #expect(j.map(\.title) == ["Quarterly plan"])
        #expect(j.first?.kind == .mail)
        try await engine.forgetJournal()
        #expect(try await engine.journal(now: tenAM).isEmpty)
    }
}

@Suite struct DemoCleanup {
    @Test func simulationsLeaveNoTrace() async throws {
        let store = try HushStore(path: ":memory:")
        let e = DecisionEngine(store: store, classifier: FixedClassifier(level: .ambient, confidence: 0.9))
        _ = try await e.evaluate(InboxItem(id: "demo:1", kind: .mail, senderAddress: "sam@example.com", subject: "s", receivedAt: tenAM), now: tenAM)
        _ = try await e.evaluate(InboxItem(id: "agent:\(HushStore.demoSessionPrefix)00000000a001:approval:1", kind: .agent,
                                           subject: "s", receivedAt: tenAM, project: "web"), preset: .gentle, now: tenAM)
        _ = try await e.evaluate(mail("real", subject: "Quarterly plan"), now: tenAM)
        #expect(try await e.forgetDemoData() == 2)
        #expect(try await e.journal(now: tenAM).map(\.title) == ["Quarterly plan"])
    }
}
