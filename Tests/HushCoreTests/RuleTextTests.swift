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
