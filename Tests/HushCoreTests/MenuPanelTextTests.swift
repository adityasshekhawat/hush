import Foundation
import Testing
@testable import HushCore

@Suite struct MenuPanelWords {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    let now = Date(timeIntervalSince1970: 1_792_231_200)   // 10:00 UTC

    @Test func whatWaitsComesFirst() {
        let s = MenuPanelText.situation(waiting: ["Claude in hush"], pausedUntil: now.addingTimeInterval(600), setupLeft: 2,
                                        focused: true, asleep: true)
        #expect(s == .waiting(["Claude in hush"]))
        #expect(MenuPanelText.situation(waiting: [], pausedUntil: now, setupLeft: 2, focused: false, asleep: false) == .paused(until: now))
        #expect(MenuPanelText.situation(waiting: [], pausedUntil: nil, setupLeft: 1, focused: true, asleep: false) == .setup(stepsLeft: 1))
        #expect(MenuPanelText.situation(waiting: [], pausedUntil: nil, setupLeft: 0, focused: false, asleep: false) == .quiet)
    }

    @Test func headersAreSentences() {
        let one = MenuPanelText.header(.waiting(["Claude in hush"]), now: now, calendar: cal)
        #expect(one.title == "1 thing needs you" && one.subtitle == "Claude in hush" && one.dot == .needsYou)
        let many = MenuPanelText.header(.waiting(["Claude in hush", "a meeting soon", "Codex in api"]), now: now, calendar: cal)
        #expect(many.title == "3 things need you" && many.subtitle == "Claude in hush · a meeting soon · 1 more")
        let paused = MenuPanelText.header(.paused(until: now.addingTimeInterval(3600)), now: now, calendar: cal)
        #expect(paused.title == "Paused until 11:00" && paused.subtitle == "I'll keep what comes in for later" && paused.dot == .paused)
        #expect(MenuPanelText.header(.setup(stepsLeft: 1), now: now).subtitle == "One step left")
        #expect(MenuPanelText.header(.quiet, now: now).title == "All quiet")
        // Every expression the header asks for exists in the pack.
        for s: MenuPanelText.Situation in [.waiting(["x"]), .paused(until: now), .setup(stepsLeft: 1), .focused, .asleep, .quiet] {
            let e = MenuPanelText.header(s, now: now).expression
            #expect(["surprised", "sleepy", "happy", "neutral"].contains(e))
        }
    }

    @Test func zerosBecomeOneFriendlySentence() {
        #expect(MenuPanelText.today(held: 0, shown: 0) == nil)
        #expect(MenuPanelText.today(held: 63, shown: 4)! == ("63", "4 shown to you · Open journal"))
    }

    @Test func agentsLine() {
        #expect(MenuPanelText.agents(watching: false, needsUpdate: false, running: 0, needsYou: 0).state == .notConnected)
        #expect(MenuPanelText.agents(watching: true, needsUpdate: true, running: 2, needsYou: 0).state == .needsUpdate)
        #expect(MenuPanelText.agents(watching: true, needsUpdate: false, running: 1, needsYou: 1) == ("1 needs you · 1 running", .needsYou))
        #expect(MenuPanelText.agents(watching: true, needsUpdate: false, running: 2, needsYou: 0) == ("2 sessions running", .running))
        #expect(MenuPanelText.agents(watching: true, needsUpdate: false, running: 0, needsYou: 0) == ("Watching · nothing running", .idle))
    }

    @Test func smallLines() {
        #expect(MenuPanelText.away(sessions: 3, minutes: 40) == "3 sessions ran · 40 min")
        #expect(MenuPanelText.away(sessions: 1, minutes: 75) == "1 session ran · 1 h 15 min")
        #expect(MenuPanelText.ask(questionsThisMonth: 13) == "13 questions this month")
        #expect(MenuPanelText.waitingRows(3) == (3, 0))
        #expect(MenuPanelText.waitingRows(5) == (2, 3))
    }

    @Test func sessionCounts() {
        var t = AgentSessionTracker()
        let e = { (id: String, k: AgentSessionEvent.Kind, sec: Double) in
            AgentSessionEvent(sessionID: id, cwd: "/Users/x/Developer/hush", kind: k, at: self.now.addingTimeInterval(sec))
        }
        _ = t.handle(e("a", .prompt, 0), frontmostApp: nil)
        _ = t.handle(e("b", .prompt, 0), frontmostApp: nil)
        _ = t.handle(e("b", .needsYou, 30), frontmostApp: nil)
        _ = t.handle(e("c", .prompt, 0), frontmostApp: nil)
        _ = t.handle(e("c", .stop, 30), frontmostApp: nil)
        #expect(t.counts(now: now.addingTimeInterval(60)) == (1, 1))
        // Gone quiet for longer than staleAfter: not running any more.
        #expect(t.counts(now: now.addingTimeInterval(20 * 60)) == (0, 0))
    }
}
