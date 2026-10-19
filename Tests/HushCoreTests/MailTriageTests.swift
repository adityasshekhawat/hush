import Foundation
import Testing
@testable import HushCore

@Suite struct MailTriageRules {
    @Test func promptCarriesOnlySenderSubjectAndAClippedSnippet() {
        let long = String(repeating: "word ", count: 200)
        let item = InboxItem(id: "1", kind: .mail, senderName: "Priya", senderAddress: "priya@work.com",
                             subject: "Re: Q4 plan\nsign-off", snippet: long, receivedAt: tenAM)
        let p = MailTriage.prompt(for: item)
        #expect(p.contains("From: Priya <priya@work.com>"))
        #expect(p.contains("Subject: Re: Q4 plan sign-off"))
        #expect(p.split(separator: "\n").count == 3)
        #expect(p.count < 700)
        #expect(MailTriage.prompt(for: InboxItem(id: "2", kind: .mail, subject: "hi", receivedAt: tenAM)).contains("From: unknown"))
    }

    @Test func levelsReadQuietlyAndSurenessMapsAcrossTheThreshold() {
        let threshold = HushSettings().confidenceThreshold
        let sure = MailTriage.classification(level: "gentle", sure: true)
        #expect(sure.level == .gentle && sure.confidence > threshold)
        #expect(MailTriage.classification(level: "gentle", sure: false).confidence < threshold)
        #expect(MailTriage.classification(level: " Gentle", sure: true).level == .gentle)
        // Anything unexpected, including a model that tries to interrupt, stays quiet.
        #expect(MailTriage.classification(level: "interrupt", sure: true).level == .ambient)
        #expect(MailTriage.classification(level: "", sure: false).level == .ambient)
        #expect(MailTriage.classification(level: "ambient", sure: true).modelVersion == MailTriage.version)
    }

    @Test func gistsAreOneTidyLine() {
        #expect(MailTriage.cleanGist("\"asks if you're free for lunch\"\n") == "Asks if you're free for lunch")
        #expect(MailTriage.cleanGist("  needs   your\nsign-off  ") == "Needs your sign-off")
        #expect(MailTriage.cleanGist("Needs your signature by Friday.") == "Needs your signature by Friday")
        #expect(MailTriage.cleanGist("ok") == nil)
        #expect(MailTriage.cleanGist("   ") == nil)
        let long = MailTriage.cleanGist(String(repeating: "approve the budget ", count: 10))!
        #expect(long.count <= MailTriage.maxGist && long.hasSuffix("…") && !long.contains("  "))
    }

    @Test func modelCanNeverInterruptThroughTheEngine() async throws {
        // The engine already caps a model's interrupt at gentle (FR-5); the triage can't even ask for one.
        let e = DecisionEngine(store: try HushStore(path: ":memory:"),
                               classifier: FixedClassifier(level: MailTriage.classification(level: "gentle", sure: true).level,
                                                           confidence: 0.85))
        let d = try #require(await e.evaluate(mail("t", from: "sam@work.com", subject: "lunch?"), now: tenAM))
        #expect(d.finalLevel == .gentle)
    }
}
