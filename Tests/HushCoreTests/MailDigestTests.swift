import Foundation
import Testing
@testable import HushCore

@Suite struct MailDigests {
    func e(_ who: String, _ outcome: Decision.Outcome, _ reasons: String, _ title: String = "s") -> LoggedDecision {
        LoggedDecision(id: UUID().uuidString, at: tenAM, category: "mail:" + who, finalLevel: nil, outcome: outcome,
                       confidence: nil, modelVersion: nil, reasons: reasons, response: nil, kind: .mail, title: title)
    }

    @Test func countsWhatWasHeldBack() {
        let d = MailDigest.build([
            e("priya@acme.io", .ambient, "model: gentle @ 0.85 | quiet hours → ambient", "Q4 plan"),
            e("sam@x.com", .ambient, "model: ambient @ 0.85"),
            e("figma@x.com", .ambient, "model: ambient @ 0.60"),
            e("news@shop.com", .dropped, "bulk headers"),
            e("boss@acme.io", .shown, "VIP"),                              // shown: not in the digest
            e(MailDigest.ownAddress, .shown, "computed in code (mail)"),   // the digest itself
        ])
        #expect(d?.total == 4)
        #expect(d?.title == "4 mails while you were busy")
        #expect(d?.summary == "1 might need you · 2 could wait · 1 newsletter")
        #expect(d?.lines == "priya@acme.io: Q4 plan")
    }

    @Test func tooFewIsntWorthAVisit() {
        #expect(MailDigest.build([e("a@x.com", .ambient, "model: ambient @ 0.9"), e("b@x.com", .dropped, "bulk headers")]) == nil)
    }
}
