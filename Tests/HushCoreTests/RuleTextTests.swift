import Foundation
import Testing
@testable import HushCore

@Suite struct RuleSentences {
    let base = UserRule(id: "r1", match: .sender("news@shop.com"), action: .never, createdAt: Date(timeIntervalSince1970: 0))

    @Test func sentencesAreFirstPerson() {
        #expect(RuleText.sentence(base) == "I'll hold back mail from news@shop.com.")
        #expect(RuleText.sentence(UserRule(match: .category("meeting"), action: .alwaysInterrupt)) == "I'll always tap the glass for meeting reminders.")
        #expect(RuleText.sentence(UserRule(match: .category("agent:hush"), action: .never)) == "I'll hold back agent updates in hush.")
        #expect(RuleText.sentence(UserRule(match: .senderDomain("shop.com"), action: .alwaysGentle)) == "I'll always show you mail from anyone at shop.com.")
    }

    @Test func roundTripsAndEdits() {
        #expect(RuleText.parse(RuleText.sentence(base), base: base) == base)
        let edited = RuleText.parse("Always show me mail from anyone at shop.com", base: base)
        #expect(edited?.match == .senderDomain("shop.com"))
        #expect(edited?.action == .alwaysGentle)
        #expect(edited?.id == "r1")
        #expect(RuleText.parse("hold back mail from @news.com.", base: base)?.match == .senderDomain("news.com"))
        #expect(RuleText.parse("Hide meetings", base: base)?.match == .category("meeting"))
    }

    @Test func unclearEditsDontParse() {
        #expect(RuleText.parse("Newsletters can wait until the evening", base: base) == nil)
        #expect(RuleText.parse("hold back mail from somebody", base: base) == nil)
        #expect(RuleText.parse("", base: base) == nil)
    }
}

@Suite struct RuleSuggesting {
    @Test func onlyParsedSentencesBecomeRules() {
        let rules = RuleSuggestions.rules(from: [
            "Always show me mail from anyone at acme.com",
            "Always tap the glass for mail from boss@acme.com.",
            "Hold back mail from anyone at shop.com",
            "Always show me mail from my manager",          // no address: dropped
            "Always show me mail from anyone at acme.com",  // repeat: dropped
            "Sure, here are your rules:",                   // chatter: dropped
            "Hold back agent updates in scratch project folder",
        ], now: tenAM)
        #expect(rules.map(RuleText.sentence) == [
            "I'll always show you mail from anyone at acme.com.",
            "I'll always tap the glass for mail from boss@acme.com.",
            "I'll hold back mail from anyone at shop.com.",
            "I'll hold back agent updates in scratch.",
        ])
    }
}

@Suite struct SubjectRules {
    @Test func wordsInTheSubjectBecomeRules() {
        let base = UserRule(id: "r", match: .category("meeting"), action: .never, createdAt: tenAM)
        let r = RuleText.parse("Always tap the glass for mail about “Outage”", base: base)
        #expect(r?.match == .subjectContains("outage") && r?.action == .alwaysInterrupt)
        #expect(RuleText.sentence(r!) == "I'll always tap the glass for mail about “outage”.")
        #expect(RuleText.parse(RuleText.sentence(r!), base: base) == r)
        #expect(RuleText.parse("Always show me mail about x", base: base) == nil)            // too short
        #expect(r!.matches(mail("1", subject: "SEV1: outage in eu-west")))
        #expect(!r!.matches(mail("2", subject: "Weekly digest")))
    }

    @Test func subjectRulesCanInterruptThroughTheEngine() async throws {
        let e = DecisionEngine(store: try HushStore(path: ":memory:"), classifier: FixedClassifier(level: .ambient, confidence: 0.9))
        try await e.addRule(UserRule(match: .subjectContains("outage"), action: .alwaysInterrupt, createdAt: tenAM))
        let d = try #require(await e.evaluate(mail("o", from: "alerts@x.com", subject: "Outage: api down"), now: tenAM))
        #expect(d.finalLevel == .interrupt)
    }
}

@Suite struct RulesBeatBulk {
    @Test func yourRuleWinsOverTheBulkFilter() async throws {
        let e = DecisionEngine(store: try HushStore(path: ":memory:"), classifier: FixedClassifier(level: .ambient, confidence: 0.9))
        try await e.addRule(UserRule(match: .subjectContains("outage"), action: .alwaysInterrupt, createdAt: tenAM))
        let alert = try #require(await e.evaluate(mail("a", from: "noreply@status.io", subject: "Outage in eu-west"), now: tenAM))
        #expect(alert.finalLevel == .interrupt)
        // Other bulk mail is still dropped.
        let news = try #require(await e.evaluate(mail("b", from: "noreply@status.io", subject: "Monthly summary"), now: tenAM))
        #expect(news.outcome == .dropped)
    }
}
