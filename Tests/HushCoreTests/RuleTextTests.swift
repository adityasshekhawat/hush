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
