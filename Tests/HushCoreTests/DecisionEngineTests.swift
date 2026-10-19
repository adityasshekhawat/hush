import Foundation
import Testing
@testable import HushCore

/// Classifier stub that returns whatever the test says.
struct FixedClassifier: AttentionClassifier {
    var level: AttentionLevel
    var confidence: Double
    let version = "fixed-1"
    func classify(_ item: InboxItem) async -> Classification {
        Classification(level: level, confidence: confidence, modelVersion: version)
    }
}

let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// 2026-10-17 10:00 UTC
let tenAM = Date(timeIntervalSince1970: 1_792_231_200)

func mail(_ id: String, from: String = "priya@work.com", subject: String = "Quarterly plan",
          headers: [String: String] = [:], at: Date = tenAM) -> InboxItem {
    InboxItem(id: id, kind: .mail, senderName: "Priya", senderAddress: from, subject: subject,
              snippet: "Here is the draft", headers: headers, receivedAt: at)
}

func engine(_ c: AttentionClassifier = FixedClassifier(level: .gentle, confidence: 0.9),
            _ s: HushSettings = .init()) throws -> DecisionEngine {
    DecisionEngine(store: try HushStore(path: ":memory:"), classifier: c, settings: s, calendar: utc)
}

@Suite struct CascadeRules {
    @Test func bulkMailIsDroppedBeforeTheModel() async throws {
        let e = try engine(FixedClassifier(level: .interrupt, confidence: 1))
        let d = try #require(await e.evaluate(mail("1", headers: ["List-Unsubscribe": "<mailto:x>"]), now: tenAM))
        #expect(d.outcome == .dropped)
        #expect(d.modelVersion == nil)
    }

    @Test func noReplySendersAreBulk() {
        #expect(BulkMailFilter.isBulk(mail("1", from: "no-reply@shop.com")))
        #expect(BulkMailFilter.isBulk(mail("2", headers: ["Precedence": "bulk"])))
        #expect(!BulkMailFilter.isBulk(mail("3")))
    }

    @Test func vipInterrupts() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9), .init(vips: ["Boss@Work.com"]))
        let d = try #require(await e.evaluate(mail("1", from: "boss@work.com"), now: tenAM))
        #expect(d.finalLevel == .interrupt)
        #expect(d.outcome == .shown)
    }

    @Test func vipDomainEntryMatches() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9), .init(vips: ["@family.org"]))
        let d = try #require(await e.evaluate(mail("1", from: "mum@family.org"), now: tenAM))
        #expect(d.finalLevel == .interrupt)
    }

    @Test func modelAloneCannotInterrupt() async throws {
        let e = try engine(FixedClassifier(level: .interrupt, confidence: 0.99))
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        #expect(d.finalLevel == .gentle)
    }

    @Test func lowConfidenceNeverEscalatesAmbient() async throws {
        // ADR-003: unsure caps at gentle, it doesn't promote ambient to gentle.
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.3))
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        #expect(d.finalLevel == .ambient)
        #expect(d.outcome == .ambient)
    }

    @Test func notThisKindAgainDropsFutureMailFromSender() async throws {
        let e = try engine()
        let first = try #require(await e.evaluate(mail("1"), now: tenAM))
        try await e.notThisKindAgain(first, now: tenAM)
        let second = try #require(await e.evaluate(mail("2"), now: tenAM))
        #expect(second.outcome == .dropped)
        let other = try #require(await e.evaluate(mail("3", from: "sam@work.com"), now: tenAM))
        #expect(other.outcome == .shown)
    }

    @Test func alwaysInterruptRuleBeatsModel() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9))
        try await e.addRule(UserRule(match: .senderDomain("work.com"), action: .alwaysInterrupt))
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        #expect(d.finalLevel == .interrupt)
    }

    @Test func duplicateItemIsIgnored() async throws {
        let e = try engine()
        #expect(try await e.evaluate(mail("1"), now: tenAM) != nil)
        #expect(try await e.evaluate(mail("1"), now: tenAM) == nil)
    }
}

@Suite struct Gates {
    @Test func dailyCapDowngradesInterrupts() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9),
                           .init(maxInterruptsPerDay: 2, vips: ["boss@work.com"]))
        var levels: [AttentionLevel?] = []
        for i in 0..<4 {
            levels.append(try await e.evaluate(mail("\(i)", from: "boss@work.com"), now: tenAM)?.finalLevel)
        }
        #expect(levels == [.interrupt, .interrupt, .gentle, .gentle])
    }

    @Test func capResetsNextDay() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9),
                           .init(maxInterruptsPerDay: 1, vips: ["boss@work.com"]))
        _ = try await e.evaluate(mail("a", from: "boss@work.com"), now: tenAM)
        let tomorrow = tenAM.addingTimeInterval(86_400)
        let d = try #require(await e.evaluate(mail("b", from: "boss@work.com"), now: tomorrow))
        #expect(d.finalLevel == .interrupt)
    }

    @Test func quietHoursWrapPastMidnight() {
        let q = QuietHours(start: (22, 0), end: (7, 0))
        #expect(q.contains(tenAM.addingTimeInterval(13 * 3600), calendar: utc))  // 23:00
        #expect(q.contains(tenAM.addingTimeInterval(-4 * 3600), calendar: utc))  // 06:00
        #expect(!q.contains(tenAM, calendar: utc))
    }

    @Test func quietHoursHoldMailAsAmbient() async throws {
        let e = try engine(FixedClassifier(level: .gentle, confidence: 0.9),
                           .init(quietHours: QuietHours(start: (9, 0), end: (11, 0))))
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        #expect(d.finalLevel == .ambient)
    }

    @Test func busyQueuesThenReleases() async throws {
        let e = try engine()
        _ = try await e.setFocus(UserFocus(inCall: true), now: tenAM)
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        #expect(d.outcome == .queued)
        #expect(await e.queuedCount == 1)
        let released = try await e.setFocus(.idle, now: tenAM.addingTimeInterval(600))
        #expect(released.map(\.outcome) == [.shown])
        #expect(await e.queuedCount == 0)
    }

    @Test func staleMeetingRemindersAreDroppedOnRelease() async throws {
        let e = try engine()
        let m = Meeting(id: "m", title: "Standup", start: tenAM.addingTimeInterval(120), end: tenAM.addingTimeInterval(1800))
        _ = try await e.setFocus(UserFocus(fullScreen: true), now: tenAM)
        let r = MeetingReminder(meeting: m, level: .interrupt, fireAt: tenAM)
        _ = try await e.evaluate(r.item, preset: r.level, now: tenAM)
        let released = try await e.setFocus(.idle, now: tenAM.addingTimeInterval(300))
        #expect(released.isEmpty)
    }

    @Test func ambientItemsAreNotQueuedWhileBusy() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9))
        _ = try await e.setFocus(UserFocus(inCall: true), now: tenAM)
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        #expect(d.outcome == .ambient)
    }
}

@Suite struct Signals {
    @Test func threeShoosLowerThatType() async throws {
        let e = try engine()
        for i in 0..<3 {
            let d = try #require(await e.evaluate(mail("s\(i)"), now: tenAM))
            #expect(d.finalLevel == .gentle)
            try await e.record(.shooed, for: d, now: tenAM)
        }
        let after = try #require(await e.evaluate(mail("s3"), now: tenAM))
        #expect(after.finalLevel == .ambient)
        let otherSender = try #require(await e.evaluate(mail("o", from: "sam@work.com"), now: tenAM))
        #expect(otherSender.finalLevel == .gentle)
    }

    @Test func daySummaryCountsHeldBack() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9), .init(vips: ["boss@work.com"]))
        _ = try await e.evaluate(mail("v", from: "boss@work.com"), now: tenAM)
        for i in 0..<5 { _ = try await e.evaluate(mail("a\(i)"), now: tenAM) }
        _ = try await e.evaluate(mail("b", headers: ["List-Id": "x"]), now: tenAM)
        let s = try await e.daySummary(now: tenAM)
        #expect(s == DaySummary(shown: 1, heldBack: 6))
    }

    @Test func queuedThenShownCountsOnce() async throws {
        let e = try engine()
        _ = try await e.setFocus(UserFocus(typing: true), now: tenAM)
        _ = try await e.evaluate(mail("1"), now: tenAM)
        _ = try await e.setFocus(.idle, now: tenAM)
        #expect(try await e.daySummary(now: tenAM) == DaySummary(shown: 1, heldBack: 0))
    }

    @Test func decisionLogKeepsModelVersionAndResponse() async throws {
        let e = try engine()
        let d = try #require(await e.evaluate(mail("1"), now: tenAM))
        try await e.record(.opened, for: d, now: tenAM)
        let log = try await e.recentDecisions(limit: 1)
        #expect(log.first?.modelVersion == "fixed-1")
        #expect(log.first?.response == .opened)
        #expect(log.first?.confidence == 0.9)
    }
}

@Suite struct RulesOnly {
    @Test func neverInterruptsAndIsAlwaysUnsure() async {
        let c = RulesOnlyClassifier()
        let r = await c.classify(mail("1", subject: "URGENT: approve by EOD"))
        #expect(r.level == .gentle)
        #expect(r.confidence < HushSettings().confidenceThreshold)
        let plain = await c.classify(mail("2", subject: "Lunch photos"))
        #expect(plain.level == .ambient)
    }

    @Test func gistStripsReplyPrefixes() async {
        let g = await SubjectGistWriter().gist(for: mail("1", subject: "Re: Fwd: Budget"))
        #expect(g == "Priya: Budget")
    }
}

@Suite struct HeldBackLines {
    @Test func dayAndWeekLines() {
        #expect(DaySummary(shown: 4, heldBack: 63).dayLine == "You got 4 things from me today. I held back 63.")
        #expect(DaySummary(shown: 1, heldBack: 2).weekLine == "This week you got 1 thing from me. I held back 2.")
        #expect(DaySummary(shown: 0, heldBack: 0).weekLine == "Quiet week. Nothing needed you.")
    }
}

@Suite struct HeldBackLedger {
    @Test func groupsWhatWasHeldAndSkipsWhatShowed() async throws {
        let e = try engine(FixedClassifier(level: .ambient, confidence: 0.9))
        _ = try await e.evaluate(mail("1", from: "news@shop.com"), now: tenAM)
        _ = try await e.evaluate(mail("2", from: "news@shop.com"), now: tenAM)
        _ = try await e.evaluate(mail("3", from: "deals@store.com"), now: tenAM)
        let held = try await e.heldToday(now: tenAM)
        #expect(held.first?.label == "mail from news@shop.com")
        #expect(held.first?.count == 2)
        #expect(held.map(\.count).reduce(0, +) == 3)
        #expect(try await e.weekDays(now: tenAM).count == 5)
    }
}
