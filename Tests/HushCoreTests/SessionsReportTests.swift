import Foundation
import Testing
@testable import HushCore

@Suite struct SessionsReports {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func session(_ cwd: String, working: TimeInterval? = nil, waiting: Bool = false, last: TimeInterval = 60, agent: AgentKind = .claude) -> AgentSessionTracker.Session {
        var s = AgentSessionTracker.Session(cwd: cwd, app: "com.apple.Terminal", lastEvent: now.addingTimeInterval(-last))
        s.workingSince = working.map { now.addingTimeInterval(-$0) }
        s.waitingForYou = waiting
        s.agent = agent
        return s
    }

    @Test func liveStateSortsWaitingFirstAndReadsPlainly() {
        let live = ["a": session("/x/hush", working: 360), "b": session("/x/site", waiting: true, agent: .codex),
                    "c": session("/x/old", last: 7 * 3600)]
        let lines = SessionsReport.lines(live: live, digests: [], now: now)
        #expect(lines.map(\.project) == ["site", "hush"])          // stale one dropped, waiting first
        #expect(SessionsReport.headline(lines) == "2 sessions: 1 needs you, 1 working.")
        #expect(SessionsReport.statusText(lines[1], now: now) == "working for 6 min")
        #expect(lines[0].agent == .codex)
        #expect(SessionsReport.plainText(lines, now: now).contains("site, Codex: needs you."))
    }

    @Test func transcriptsFillInWhatHappened() {
        let d = SessionDigest(sessionID: "a", cwd: "/x/hush", branch: "main", title: "Polish the panel", prompts: 2,
                              firstPrompt: "polish", lastPrompt: "make the held row fit", filePaths: ["/x/hush/MenuPanel.swift"],
                              commands: 3, commits: 1, pullRequests: [], lastMessage: "Done, it fits now.",
                              start: now.addingTimeInterval(-900), end: now.addingTimeInterval(-120), status: .finished)
        let lines = SessionsReport.lines(live: ["a": session("/x/hush", last: 120)], digests: [d], now: now)
        #expect(lines.first?.lastPrompt == "make the held row fit")
        #expect(lines.first?.files == ["MenuPanel.swift"])
        #expect(lines.first?.status == .finished)
        #expect(SessionsReport.headline([]) == "No sessions in the last few hours.")
    }

    @Test func spotsSessionQuestionsNotGeneralClaudeOnes() {
        #expect(SessionQuestion.matches("waht's happening in claude Code right now ?"))
        #expect(SessionQuestion.matches("Is my agent done yet"))
        #expect(!SessionQuestion.matches("is claude better than chatgpt"))
        #expect(!SessionQuestion.matches("help me write a note"))
        #expect(SessionQuestion.matches("what all claude sessions are running ?"))
        #expect(SessionQuestion.matches("which agents are still working"))
        #expect(!SessionQuestion.matches("claude code tutorial for beginners"))
    }
}

@Suite struct HushCommands {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func line(_ id: String, _ project: String, _ status: SessionLine.Status) -> SessionLine {
        SessionLine(id: id, agent: .claude, project: project, branch: nil, status: status, app: nil, tty: nil, title: nil,
                    lastPrompt: nil, lastMessage: nil, files: [], commits: 0, pullRequests: [], lastActivity: now, digest: nil)
    }

    @Test func parsesCommandsToHush() {
        #expect(HushCommand.parse("keep watching this session, let me know when it finishes") == .watch)
        #expect(HushCommand.parse("tell me when claude is done in site") == .watch)
        #expect(HushCommand.parse("stop watching site") == .unwatch)
        #expect(HushCommand.parse("what's happening in hush") == nil)
    }

    @Test func picksTheSessionYouMean() {
        let s = [line("a", "hush", .working(since: now)), line("b", "site", .finished)]
        #expect(HushCommand.target("let me know when site finishes", sessions: s, selected: nil) == .one("b"))
        #expect(HushCommand.target("let me know when it finishes", sessions: s, selected: nil) == .one("a"))   // the only working one
        #expect(HushCommand.target("anything", sessions: s, selected: "b") == .one("b"))
        let two = [line("a", "hush", .working(since: now)), line("c", "notes", .working(since: now))]
        #expect(HushCommand.target("let me know when it finishes", sessions: two, selected: nil) == .ambiguous(["a", "c"]))
    }

    @Test func aWatchedSessionAlwaysReportsItsFinish() {
        var t = AgentSessionTracker()
        t.watch("s1")
        let at = { (k: AgentSessionEvent.Kind, sec: TimeInterval) in
            AgentSessionEvent(sessionID: "s1", cwd: "/x/hush", kind: k, app: "com.apple.Terminal", at: Date(timeIntervalSince1970: sec))
        }
        _ = t.handle(at(.prompt, 0), frontmostApp: "com.apple.Terminal")
        let out = t.handle(at(.stop, 20), frontmostApp: "com.apple.Terminal")     // short, and you're watching it
        #expect(out.first?.id.contains(":watched:") == true)
        #expect(out.first?.snippet.contains("you asked me to watch it") == true)
        #expect(t.watched.isEmpty)                                               // one-shot
    }
}

@Suite struct TerminalScripts {
    @Test func quotesSafelyOnOneLine() {
        #expect(TerminalScript.quote("say \"hi\"\nthen \\ stop") == #""say \"hi\" then \\ stop""#)
    }

    @Test func onlyScriptableTerminalsAndRealTTYs() {
        #expect(TerminalScript.source(bundleID: "com.apple.Terminal", tty: "/dev/ttys003", text: "yes")?.contains(#"do script "yes" in t"#) == true)
        #expect(TerminalScript.source(bundleID: "com.googlecode.iterm2", tty: "/dev/ttys003", text: "go")?.contains(#"write text "go""#) == true)
        #expect(TerminalScript.source(bundleID: "dev.warp.Warp-Stable", tty: "/dev/ttys003", text: "x") == nil)
        #expect(TerminalScript.source(bundleID: "com.apple.Terminal", tty: "/dev/ttys003\" & do shell script \"x", text: "x") == nil)
    }
}
