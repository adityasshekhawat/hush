import Foundation
import Testing
@testable import HushCore

@Suite struct CharacterArt {
    func d(_ id: String, _ kind: ItemKind = .agent, level: AttentionLevel = .gentle, subject: String = "x",
           startsAt: Date? = nil, project: String? = "hush", at: Date = tenAM) -> Decision {
        let i = InboxItem(id: id, kind: kind, subject: subject, receivedAt: at, startsAt: startsAt, project: project)
        return Decision(id: id, at: at, item: i, proposedLevel: level, finalLevel: level, outcome: .shown,
                        confidence: 1, modelVersion: "code", reasons: [])
    }

    @Test func agentsHoldUpWhatTheyAreAbout() {
        #expect(CharacterVariant.of(state: .notice, active: d("agent:s:approval:1"), now: tenAM) == .init("needs"))
        #expect(CharacterVariant.of(state: .notice, active: d("agent:s:approval:1:risky"), now: tenAM)
                == .init("careful", labels: ["card": "Look carefully"]))
        #expect(CharacterVariant.of(state: .hold, active: d("agent:s:error:1"), now: tenAM) == .init("error"))
        #expect(CharacterVariant.of(state: .hold, active: d("agent:s:done:1"), now: tenAM) == .init())
        #expect(CharacterVariant.of(state: .peek, active: nil, now: tenAM) == .init())
    }

    @Test func meetingsCheckTheWatchThenHoldTheDoor() {
        let start = tenAM.addingTimeInterval(60)
        let soon = d("m", .meeting, subject: "Design review with the whole platform team", startsAt: start)
        #expect(CharacterVariant.of(state: .clock, active: soon, now: tenAM)
                == .init("meeting", labels: ["card": "Design review with the whole platform…"]))
        let now = d("m", .meeting, level: .interrupt, startsAt: start)
        #expect(CharacterVariant.of(state: .tap, active: now, now: tenAM).name == "door")
        #expect(CharacterVariant.of(state: .tap, active: now, now: start.addingTimeInterval(30)).name == "late")
        #expect(CharacterVariant.of(state: .hurry, active: d("v", .mail, level: .interrupt), now: tenAM).name == "mail")
    }

    @Test func flagRailShowsWhatWaitsBehindHush() {
        let held = d("agent:a:approval:1", project: "api")
        let others = (1...3).map { d("agent:s\($0):done:1", project: "p\($0)", at: tenAM.addingTimeInterval(Double($0))) }
        let rail = FlagRail.layout(waiting: [held] + others + [d("mail", .mail)])
        #expect(rail.more == 0)
        #expect(rail.flags.map(\.project) == ["p3", "p2", "p1"])
        #expect(FlagRail.layout(waiting: [held]).flags.isEmpty)
        let many = (1...7).map { d("agent:s\($0):error:1", project: "p\($0)", at: tenAM.addingTimeInterval(Double($0))) }
        let full = FlagRail.layout(waiting: [held] + many)
        #expect(full.flags.count == 4 && full.more == 3 && full.flags.allSatisfy { $0.kind == .error })
        #expect(FlagRail.kind(of: held.item) == .needs)
    }
}
