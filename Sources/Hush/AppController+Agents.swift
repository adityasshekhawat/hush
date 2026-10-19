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
