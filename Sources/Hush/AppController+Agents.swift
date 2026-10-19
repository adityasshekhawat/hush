import AppKit
import HushCore
import HushMac
import SwiftUI

/// Claude Code sessions (Phase 1), the command box (⌘⇧H), opt-in moods and inbox zero.
extension AppController {
    func agentEvent(_ e: AgentSessionEvent) {
        if let app = e.app { sessionApps[e.sessionID] = app }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        // Scrutable: which agent said what (not every tool call; those are frequent).
        if e.kind != .tool {
            DiagnosticsLog.write("agent: \(e.agent.rawValue) \(e.kind.rawValue) in \(e.project)\(e.app != nil && e.app == front ? " (you're watching it)" : "")")
        }
        for item in agentSessions.handle(e, frontmostApp: front) {
            // You asked to be told when this one finished: that's your rule, so it may tap the glass.
            submit(item, preset: item.id.contains(":watched:") ? .interrupt : .gentle)
        }
        // The approval was answered or the run ended: put away any card still asking about it.
        if e.kind == .tool || e.kind == .stop || e.kind == .end {
            let stale = waiting.filter { $0.item.kind == .agent && $0.item.id.hasPrefix("agent:\(e.sessionID):approval:") }
            if !stale.isEmpty {
                if let a = active, stale.contains(where: { $0.id == a.id }) { envelope.close(); resolveActive(.opened) }
                waiting.removeAll { d in stale.contains { $0.id == d.id } }
            }
        }
        refresh()
    }

    /// "Also waiting: api (needs you), web (finished)": the other agent sessions in line behind this card (ADR-024).
    func alsoWaiting(besides a: Decision) -> String {
        let others = waiting.filter { $0.id != a.id && AgentSessionTracker.sessionID(ofItem: $0.item.id) != nil }
        guard !others.isEmpty else { return "" }
        let parts = others.prefix(3).map { d -> String in
            let what = d.item.id.contains(":approval:") ? "needs you" : d.item.id.contains(":error:") ? "stopped" : "finished"
            return "\(d.item.project ?? "a session") (\(what))"
        }
        return "Also waiting: " + parts.joined(separator: ", ") + (others.count > 3 ? ", and \(others.count - 3) more" : "")
    }

    /// You switched to the app a session runs in: its cards have done their job. Only when that app hosts one waiting
    /// session, because with several tabs Hush can't tell which one you're looking at (ADR-024).
    func agentAppCameForward(_ bundleID: String) {
        let here = waiting.filter { $0.item.kind == .agent && $0.item.sourceApp == bundleID
            && AgentSessionTracker.sessionID(ofItem: $0.item.id) != nil }
        let sessions = Set(here.compactMap { AgentSessionTracker.sessionID(ofItem: $0.item.id) })
        guard sessions.count == 1 else { return }
        // A risky approval stays: it asks for a careful look, not a glance at the window.
        let clear = here.filter { !$0.item.id.hasSuffix(":risky") }
        guard !clear.isEmpty else { return }
        if let a = active, clear.contains(where: { $0.id == a.id }) { envelope.close(); resolveActive(.opened) }
        waiting.removeAll { d in clear.contains { $0.id == d.id } }
        DiagnosticsLog.write("agent: cleared \(clear.count) card(s), you went to \(bundleID)")
        refresh()
    }

    /// "1 more min": put the meeting card away and bring it back in a minute, until the late window ends (ADR-025).
    func snoozeMeeting(_ d: Decision) {
        envelope.close()
        if active?.id == d.id { resolveActive(.ignored) } else { waiting.removeAll { $0.id == d.id } }
        meetingSnoozes += 1
        var item = d.item
        item.id = d.item.id + ":snooze:\(meetingSnoozes)"
        DiagnosticsLog.write("meeting: snoozed a minute")
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, !MeetingReminderPlanner.isOver(item, now: Date()) else { return }
            item.receivedAt = Date()
            self.submit(item, preset: .interrupt)
        }
        refresh()
    }

    /// The mic came on: if a meeting starts within 10 minutes either way, you've joined it (ADR-025).
    func meetingJoined() {
        let now = Date()
        let joined = waiting.filter { d in
            d.item.kind == .meeting && d.item.startsAt.map { abs($0.timeIntervalSince(now)) < 10 * 60 } == true
        }
        guard !joined.isEmpty else { return }
        if let a = active, joined.contains(where: { $0.id == a.id }) { envelope.close(); resolveActive(.opened) }
        waiting.removeAll { d in joined.contains { $0.id == d.id } }
        DiagnosticsLog.write("meeting: call started, cleared \(joined.count) reminder(s)")
    }

    /// The spec's "useful in the first five minutes" (ADR-026): right after setup, if nothing real is waiting, show once
    /// what an alert looks like. Nothing is logged or counted: it's a demo, and it says so.
    func firstAlertDemo() {
        guard waiting.isEmpty, !defaults.bool(forKey: "firstAlertDemoShown") else { return }
        defaults.set(true, forKey: "firstAlertDemoShown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.waiting.isEmpty, !self.panelHidden else { return }
            self.previewOverride = .hold
            self.tipBubble.show("This is how I show you something: I hold it up. Click me when I do. Your first real one is on its way.",
                                above: self.cardAvoidRect(), for: 8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                if self?.previewOverride == .hold { self?.previewOverride = nil }
            }
        }
    }

    func toggleCommandBox() {
        onboarding?.observedHotkey()
        if commandPanel.isOpen { commandPanel.close(); return }
        if wanderer.isAway { wanderer.cancel(); placeAtHome() }
        renderer.react(.commandWindow)
        // An answer is showing: follow up on it, and open above the card so it stays readable.
        // At three turns the box offers "Carry on in Claude" instead of a field.
        let followUp = ask.followUpSource
        commandPanel.answerCardFrame = { [weak self] in self?.ask.card.frame }
        commandPanel.open(above: cardAvoidRect(), followUp: followUp) { [weak self] app in
            self?.lastCommandApp = app
            return self?.ask.context(frontmostApp: app) ?? AskContext()
        }
    }

    func moodTick() {
        guard moodsEnabled, let a = active, a.item.kind == .mail, a.finalLevel == .gentle else { return }
        // Only count time you could actually see it waiting.
        guard !focus.state.isBusy && !panelHidden else { return }
        moodSeconds += 30
        let stage = moodSeconds >= 40 * 60 ? 3 : moodSeconds >= 20 * 60 ? 2 : moodSeconds >= 10 * 60 ? 1 : 0
        if stage != moodStage { moodStage = stage; renderer.react(.mood(stage)) }
    }

    func resetMood() {
        moodSeconds = 0
        if moodStage != 0 { moodStage = 0; renderer.react(.mood(0)) }
    }

    /// Inbox zero: rare on purpose, at most once a day. (Real trigger arrives with the mail source.)
    func celebrateInboxZero() {
        let last = defaults.object(forKey: "lastInboxZero") as? Date
        if let last, Calendar.current.isDateInToday(last) { return }
        defaults.set(Date(), forKey: "lastInboxZero")
        renderer.react(.inboxZero)
    }

    func playCommandWindow() { renderer.react(.commandWindow) }
}
