import Foundation
import Testing
@testable import HushCore

@Suite struct AgentSessions {
    let sid = "b94d492f-0c68-4f16-8798-f06a5ff88858"
    let term = "com.apple.Terminal"

    func ev(_ k: AgentSessionEvent.Kind, _ t: TimeInterval, id: String? = nil) -> AgentSessionEvent {
        AgentSessionEvent(sessionID: id ?? sid, cwd: "/Users/x/Developer/hush", kind: k, app: term, at: tenAM.addingTimeInterval(t))
    }

    @Test func longRunWhileElsewhereEarnsAnEnvelope() {
        var t = AgentSessionTracker()
        #expect(t.handle(ev(.prompt, 0), frontmostApp: "com.google.Chrome").isEmpty)
        let out = t.handle(ev(.stop, 300), frontmostApp: "com.google.Chrome")
        #expect(out.count == 1)
        #expect(out.first?.kind == .agent)
        #expect(out.first?.subject == "Claude finished in hush")
        #expect(out.first?.snippet == "Ran for 5 min")
        #expect(out.first?.sourceApp == term)
    }

    /// 45 s is enough (ADR-035): a 50-second answer while you're in the browser is worth an envelope, 40 s isn't.
    @Test func runsOf45SecondsOrMoreCount() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt, 0), frontmostApp: "com.google.Chrome")
        #expect(t.handle(ev(.stop, 50), frontmostApp: "com.google.Chrome").first?.snippet == "Ran for 50 s")
        _ = t.handle(ev(.prompt, 100), frontmostApp: "com.google.Chrome")
        #expect(t.handle(ev(.stop, 140), frontmostApp: "com.google.Chrome").isEmpty)
        // Still nothing when you're looking at it, however long it ran.
        _ = t.handle(ev(.prompt, 200), frontmostApp: term)
        #expect(t.handle(ev(.stop, 500), frontmostApp: term).isEmpty)
    }

    @Test func codexSessionsSayCodex() {
        var t = AgentSessionTracker()
        let codex = { (k: AgentSessionEvent.Kind, at: TimeInterval) in
            AgentSessionEvent(sessionID: "019a1c2e-7d3b-7e21-9f00-1234567890ab", cwd: "/Users/x/Developer/hush", kind: k,
                              app: term, at: tenAM.addingTimeInterval(at), agent: .codex)
        }
        _ = t.handle(codex(.prompt, 0), frontmostApp: nil)
        let ask = t.handle(codex(.needsYou, 10), frontmostApp: nil)
        #expect(ask.first?.subject == "Codex needs you in hush")
        #expect(ask.first?.senderName == "Codex")
        let done = t.handle(codex(.stop, 300), frontmostApp: nil)
        #expect(done.first?.subject == "Codex finished in hush")
    }

    @Test func quickRunsAndRunsYouWatchStayQuiet() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt, 0), frontmostApp: nil)
        #expect(t.handle(ev(.stop, 30), frontmostApp: nil).isEmpty)          // quick
        _ = t.handle(ev(.prompt, 100), frontmostApp: term)
        #expect(t.handle(ev(.stop, 600), frontmostApp: term).isEmpty)        // you were watching
    }

    @Test func needsYouOncePerWaitAndClearedByProgress() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt, 0), frontmostApp: nil)
        let a = t.handle(ev(.needsYou, 10), frontmostApp: nil)
        #expect(a.map(\.id) == ["agent:\(sid):approval:1"])
        #expect(t.handle(ev(.needsYou, 12), frontmostApp: nil).isEmpty)      // same wait
        _ = t.handle(ev(.tool, 20), frontmostApp: nil)                         // approved, running again
        #expect(t.handle(ev(.needsYou, 30), frontmostApp: nil).count == 1)   // a new wait
    }

    @Test func thinkingOnlyForBackgroundWork() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt, 0), frontmostApp: nil)
        #expect(!t.workingInBackground(now: tenAM.addingTimeInterval(5), frontmostApp: nil))   // just started
        #expect(t.workingInBackground(now: tenAM.addingTimeInterval(60), frontmostApp: nil))
        #expect(!t.workingInBackground(now: tenAM.addingTimeInterval(60), frontmostApp: term)) // you're watching
        _ = t.handle(ev(.stop, 90), frontmostApp: nil)
        #expect(!t.workingInBackground(now: tenAM.addingTimeInterval(100), frontmostApp: nil))
    }

    @Test func sessionsAreIndependentAndStaleOnesExpire() {
        var t = AgentSessionTracker()
        _ = t.handle(ev(.prompt, 0, id: "a"), frontmostApp: nil)
        _ = t.handle(ev(.prompt, 0, id: "b"), frontmostApp: nil)
        _ = t.handle(ev(.end, 10, id: "a"), frontmostApp: nil)
        #expect(t.sessions.keys.sorted() == ["b"])
        t.prune(now: tenAM.addingTimeInterval(20 * 60))
        #expect(!t.workingInBackground(now: tenAM.addingTimeInterval(20 * 60), frontmostApp: nil))
    }

    @Test func agentItemsMapToPoses() {
        let done = InboxItem(id: "agent:s:done:1", kind: .agent, subject: "x", receivedAt: tenAM)
        let ask = InboxItem(id: "agent:s:approval:1", kind: .agent, subject: "x", receivedAt: tenAM)
        func d(_ i: InboxItem) -> Decision {
            Decision(id: "d", at: tenAM, item: i, proposedLevel: .gentle, finalLevel: .gentle, outcome: .shown,
                     confidence: 1, modelVersion: "code", reasons: [])
        }
        #expect(Presence.state(for: .init(active: d(done), now: tenAM)) == .hold)
        #expect(Presence.state(for: .init(active: d(ask), now: tenAM)) == .notice)
        #expect(Presence.state(for: .init(now: tenAM, agentWorking: true)) == .think)
        #expect(Presence.state(for: .init(focus: UserFocus(typing: true), now: tenAM, agentWorking: true)) == .hide)
    }

    @Test func agentItemsGoThroughTheEngineAsGentle() async throws {
        let e = try engine()
        let item = InboxItem(id: "agent:s:done:1", kind: .agent, subject: "Claude finished in hush", receivedAt: tenAM, project: "hush")
        let d = try #require(await e.evaluate(item, preset: .gentle, now: tenAM))
        #expect(d.finalLevel == .gentle)
        #expect(d.item.category == "agent:hush")
        _ = try await e.setFocus(UserFocus(inCall: true), now: tenAM)
        let queued = try #require(await e.evaluate(InboxItem(id: "agent:s:done:2", kind: .agent, subject: "y", receivedAt: tenAM), preset: .gentle, now: tenAM))
        #expect(queued.outcome == .queued)
    }
}

@Suite struct HooksConfig {
    let rtk: [String: Any] = ["model": "opus", "hooks": ["PreToolUse": [["matcher": "Bash", "hooks": [["type": "command", "command": "rtk hook claude"]]]]]]

    @Test func installKeepsExistingHooks() {
        let s = ClaudeHooksConfig.install(into: rtk, hushctl: "/Apps/Hush.app/Contents/MacOS/hushctl")
        let hooks = s["hooks"] as! [String: Any]
        #expect((hooks["PreToolUse"] as! [[String: Any]]).count == 1)       // RTK untouched
        #expect(Set(hooks.keys).isSuperset(of: Set(ClaudeHooksConfig.events)))
        #expect(s["model"] as? String == "opus")
        #expect(ClaudeHooksConfig.isInstalled(in: s))
    }

    @Test func installIsIdempotentAndUninstallRestores() throws {
        let once = ClaudeHooksConfig.install(into: rtk, hushctl: "/x/hushctl")
        let twice = ClaudeHooksConfig.install(into: once, hushctl: "/x/hushctl")
        #expect(((twice["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]).count == 1)
        let back = ClaudeHooksConfig.uninstall(from: twice)
        let a = try JSONSerialization.data(withJSONObject: back, options: .sortedKeys)
        let b = try JSONSerialization.data(withJSONObject: rtk, options: .sortedKeys)
        #expect(a == b)
        #expect(!ClaudeHooksConfig.isInstalled(in: back))
    }

    @Test func repointingOnlyTouchesHushHooks() throws {
        let old = ClaudeHooksConfig.install(into: rtk, hushctl: "/Users/x/Developer/hush/build/Hush.app/Contents/MacOS/hushctl")
        let moved = try #require(ClaudeHooksConfig.repointed(old, hushctl: "/Applications/Hush.app/Contents/MacOS/hushctl"))
        let json = String(decoding: try JSONSerialization.data(withJSONObject: moved), as: UTF8.self)
        #expect(!json.contains("Developer/hush/build"))
        #expect(json.contains("rtk hook claude"))
        #expect(ClaudeHooksConfig.repointed(moved, hushctl: "/Applications/Hush.app/Contents/MacOS/hushctl") == nil)
        #expect(ClaudeHooksConfig.repointed(rtk, hushctl: "/x") == nil)   // not installed: leave alone
    }

    @Test func codexHooksUseItsEventsAndKeepTheirAgentWhenRepointed() throws {
        let installed = ClaudeHooksConfig.install(into: [:], hushctl: "/old/hushctl", agent: .codex)
        let hooks = try #require(installed["hooks"] as? [String: Any])
        #expect(Set(hooks.keys) == Set(ClaudeHooksConfig.codexEvents))
        #expect(hooks["Notification"] == nil)
        let group = try #require((hooks["PermissionRequest"] as? [[String: Any]])?.first)
        #expect(group["matcher"] == nil)
        let cmd = try #require((group["hooks"] as? [[String: Any]])?.first?["command"] as? String)
        #expect(cmd.contains("hook --agent codex"))
        let moved = try #require(ClaudeHooksConfig.repointed(installed, hushctl: "/Applications/Hush.app/Contents/MacOS/hushctl"))
        let movedCmd = (((moved["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        #expect(movedCmd == ClaudeHooksConfig.command(hushctl: "/Applications/Hush.app/Contents/MacOS/hushctl", agent: .codex))
        #expect(ClaudeHooksConfig.uninstall(from: installed).isEmpty)
    }

    @Test func hookCommandNeverFailsOrPrints() {
        let c = ClaudeHooksConfig.command(hushctl: "/x/hushctl")
        #expect(c.hasSuffix("exit 0"))
        #expect(c.contains(">/dev/null 2>&1"))
    }
}
