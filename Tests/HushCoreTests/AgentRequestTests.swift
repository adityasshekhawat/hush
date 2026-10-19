import Foundation
import Testing
@testable import HushCore

@Suite struct AgentRequests {
    @Test func detailComesFromTheRightField() {
        #expect(AgentRequest.detail(tool: "Bash", input: ["command": "rm -rf node_modules", "description": "x"]) == "rm -rf node_modules")
        #expect(AgentRequest.detail(tool: "Edit", input: ["file_path": "/r/Sources/App.swift", "old_string": "secret"]) == "/r/Sources/App.swift")
        #expect(AgentRequest.detail(tool: "WebFetch", input: ["url": "https://example.com/a"]) == "https://example.com/a")
        #expect(AgentRequest.detail(tool: "mcp__linear__create", input: ["title": "x"]) == nil)
    }

    @Test func detailIsOneCappedLine() {
        #expect(AgentRequest.clean("make test\n\tthen\u{0007} deploy") == "make test then deploy")
        let long = AgentRequest.clean(String(repeating: "a", count: 500))!
        #expect(long.count == AgentRequest.maxDetail && long.hasSuffix("…"))
        #expect(AgentRequest.clean(" \n ") == nil)
    }

    @Test func linesReadPlainly() {
        #expect(AgentRequest(tool: "Bash", detail: "npm test").line == "wants to run npm test")
        #expect(AgentRequest(tool: "Edit", detail: "/r/Sources/App.swift").line == "wants to edit App.swift")
        #expect(AgentRequest(tool: "WebFetch", detail: "https://docs.github.com/x").line == "wants to open docs.github.com")
        #expect(AgentRequest(tool: "mcp__linear__create_issue").line == "wants to use linear (issue)")
        #expect(AgentRequest(tool: "Bash").line == "wants to run a command")
    }

    @Test func riskyRequestsAreFlaggedByRules() {
        func r(_ cmd: String) -> String? { AgentRisk.reason(AgentRequest(tool: "Bash", detail: cmd)) }
        #expect(r("rm -rf build") == "deletes files")
        #expect(r("rm -r -f ./dist") == "deletes files")
        #expect(r("git push --force origin main") == "force-pushes")
        #expect(r("git push -f") == "force-pushes")
        #expect(r("git reset --hard HEAD~3") == "throws away changes")
        #expect(r("sudo launchctl unload x") == "runs as admin")
        #expect(r("psql -c 'DROP TABLE users'") == "drops data")
        #expect(r("curl -fsSL https://x.sh | sh") == "runs a downloaded script")
        #expect(r("terraform apply -auto-approve") == "changes infrastructure")
        #expect(r("npm publish") == "publishes")
        #expect(r("./migrate.sh --env prod") == "touches production")
        #expect(r("cat .env") == "touches secrets")
        #expect(AgentRisk.reason(AgentRequest(tool: "Edit", detail: "/Users/x/.ssh/config")) == "touches secrets")
    }

    @Test func ordinaryRequestsAreNotFlagged() {
        func r(_ cmd: String) -> String? { AgentRisk.reason(AgentRequest(tool: "Bash", detail: cmd)) }
        #expect(r("npm test") == nil)
        #expect(r("git push origin feature") == nil)
        #expect(r("ls products/") == nil)
        #expect(r("swift build -c release") == nil)
        #expect(r("rm notes.txt") == nil)
        #expect(r("grep -rn tokenizer Sources") == nil)
        #expect(AgentRisk.reason(AgentRequest(tool: "Edit", detail: "/r/Sources/App.swift")) == nil)
        // A file tool isn't "deleting files" just because its path looks like a flag.
        #expect(AgentRisk.reason(AgentRequest(tool: "Write", detail: "/r/rm -rf.md")) == nil)
    }

    @Test func failuresReadAsPlainWords() {
        #expect(AgentFailure.text("rate_limit") == "Hit a usage limit")
        #expect(AgentFailure.text("authentication_failed") == "Got signed out")
        #expect(AgentFailure.text(nil) == "An error stopped it")
    }
}

@Suite struct AgentApprovals {
    let sid = "0193a1c2-7d3b-7e21-9f00-1234567890ab"
    func ev(_ kind: AgentSessionEvent.Kind, _ t: TimeInterval = 0, request: AgentRequest? = nil, failure: String? = nil) -> AgentSessionEvent {
        AgentSessionEvent(sessionID: sid, cwd: "/Users/x/Developer/hush", kind: kind, app: "com.apple.Terminal",
                          at: tenAM.addingTimeInterval(t), request: request, failure: failure)
    }

    @Test func anApprovalSaysWhatItWants() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt), frontmostApp: "com.apple.Safari")
        let items = t.handle(ev(.needsYou, 5, request: AgentRequest(tool: "Bash", detail: "npm test")), frontmostApp: "com.apple.Safari")
        #expect(items.count == 1)
        #expect(items[0].subject == "Claude needs you in hush")
        #expect(items[0].snippet == "Claude wants to run npm test")
        #expect(AgentSessionTracker.waitsForAnswer(items[0]))
        // The permission Notification that follows doesn't make a second card.
        #expect(t.handle(ev(.needsYou, 8), frontmostApp: "com.apple.Safari").isEmpty)
    }

    @Test func aRiskyApprovalAsksForACarefulLook() {
        var t = AgentSessionTracker()
        let items = t.handle(ev(.needsYou, 0, request: AgentRequest(tool: "Bash", detail: "rm -rf build")), frontmostApp: nil)
        #expect(items[0].id.hasSuffix(":risky"))
        #expect(items[0].subject == "Look carefully: Claude needs you in hush")
        #expect(items[0].snippet == "Claude wants to run rm -rf build · deletes files")
        #expect(AgentSessionTracker.rank(items[0]) == 4)
    }

    @Test func anErrorBecomesAQuietCard() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt), frontmostApp: nil)
        let items = t.handle(ev(.error, 30, failure: "rate_limit"), frontmostApp: nil)
        #expect(items.map(\.subject) == ["Claude stopped in hush"])
        #expect(items[0].snippet == "Hit a usage limit")
        #expect(AgentSessionTracker.rank(items[0]) == 1)
        #expect(!t.workingInBackground(now: tenAM.addingTimeInterval(60), frontmostApp: nil))
        // You were looking at it: no card.
        var u = AgentSessionTracker()
        #expect(u.handle(ev(.error, 30), frontmostApp: "com.apple.Terminal").isEmpty)
    }

    @Test func cardsKnowTheirSession() {
        #expect(AgentSessionTracker.sessionID(ofItem: "agent:\(sid):approval:2:risky") == sid)
        #expect(AgentSessionTracker.sessionID(ofItem: "ask:123") == nil)
    }
}

@Suite struct HookUpdates {
    @Test func olderInstallsAskForTheNewEvents() {
        let path = "/Applications/Hush.app/Contents/MacOS/hushctl"
        let current = ClaudeHooksConfig.install(into: [:], hushctl: path)
        #expect(!ClaudeHooksConfig.needsUpdate(current))
        // An install from before PermissionRequest and StopFailure.
        var hooks = current["hooks"] as! [String: Any]
        hooks["PermissionRequest"] = nil
        hooks["StopFailure"] = nil
        #expect(ClaudeHooksConfig.needsUpdate(["hooks": hooks]))
        // Not installed at all isn't "needs update".
        #expect(!ClaudeHooksConfig.needsUpdate([:]))
        // Re-installing brings it up to date and keeps one entry per event.
        let updated = ClaudeHooksConfig.install(into: ["hooks": hooks], hushctl: path)
        #expect(!ClaudeHooksConfig.needsUpdate(updated))
        #expect(((updated["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]).count == 1)
    }
}

@Suite struct AgentChannelChecks {
    let base = ["v": "1", "session": "0193a1c2-7d3b-7e21", "cwd": "/Users/x/Developer/hush"]

    @Test func acceptsWhatHushctlSends() {
        var i = base; i["event"] = "needsYou"; i["tool"] = "Bash"; i["detail"] = "rm -rf build"; i["tty"] = "/dev/ttys003"
        let e = AgentChannel.event(from: i, at: tenAM)
        #expect(e?.request == AgentRequest(tool: "Bash", detail: "rm -rf build"))
        var f = base; f["event"] = "error"; f["error"] = "rate_limit"
        #expect(AgentChannel.event(from: f, at: tenAM)?.failure == "rate_limit")
    }

    @Test func refusesAnythingElse() {
        func bad(_ change: (inout [String: String]) -> Void) -> Bool {
            var i = base; i["event"] = "needsYou"; change(&i)
            return AgentChannel.event(from: i, at: tenAM) == nil
        }
        #expect(bad { $0["extra"] = "x" })                                     // unknown key
        #expect(bad { $0["detail"] = "no tool" })                              // detail without a tool
        #expect(bad { $0["tool"] = "Bash"; $0["detail"] = "two\nlines" })      // not a cleaned line
        #expect(bad { $0["tool"] = "Bash"; $0["detail"] = String(repeating: "a", count: 300) })
        #expect(bad { $0["tool"] = "Bash; rm" })                               // odd tool name
        #expect(bad { $0["event"] = "stop"; $0["tool"] = "Bash" })             // tool only on needsYou
        #expect(bad { $0["error"] = "rate_limit" })                            // error only on error
        #expect(bad { $0["cwd"] = "relative/path" })
        #expect(bad { $0["tty"] = "/dev/disk0" })
    }
}

@Suite struct TabFocus {
    @Test func scriptsTheExactTab() {
        let t = TerminalScript.focusSource(bundleID: TerminalScript.terminal, tty: "/dev/ttys004")!
        #expect(t.contains("if tty of t is \"/dev/ttys004\"") && t.contains("set selected of t to true"))
        let i = TerminalScript.focusSource(bundleID: TerminalScript.iterm, tty: "/dev/ttys004")!
        #expect(i.contains("tell s to select"))
        #expect(TerminalScript.focusSource(bundleID: "com.mitchellh.ghostty", tty: "/dev/ttys004") == nil)
        #expect(TerminalScript.focusSource(bundleID: TerminalScript.terminal, tty: "/dev/ttys004\" & do shell script \"x") == nil)
    }
}
