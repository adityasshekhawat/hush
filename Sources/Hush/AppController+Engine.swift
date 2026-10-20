import AppKit
import HushCore
import HushMac
import SwiftUI

/// Calendar reminders and the decision engine: submitting items, focus changes, resolving appearances.
extension AppController {
    func requestCalendarAccess() async -> Bool {
        let granted = await calendar.requestAccess()
        if granted { calendar.start() }
        return granted
    }

    /// FR-6: fire any reminder that's due, then sleep until the next one. Re-run on every calendar change.
    func planReminders() {
        reminderTimer?.invalidate()
        let now = Date()
        let reminders = MeetingReminderPlanner.reminders(for: meetings, settings: settings, now: now)
        for r in reminders where r.fireAt <= now {
            submit(r.item, preset: r.level)
        }
        if let next = reminders.first(where: { $0.fireAt > now }) {
            reminderTimer = Timer.scheduledTimer(withTimeInterval: next.fireAt.timeIntervalSince(now) + 0.5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.planReminders() }
            }
        }
        // A started meeting's reminder stays for the late window ("running late"), then goes (ADR-025).
        let over = waiting.filter { MeetingReminderPlanner.isOver($0.item, now: now) }
        if let a = active, over.contains(where: { $0.id == a.id }) { envelope.close(); resolveActive(.ignored) }
        waiting.removeAll { MeetingReminderPlanner.isOver($0.item, now: now) }
        if let soonest = waiting.compactMap({ $0.item.kind == .meeting ? $0.item.startsAt : nil }).min() {
            let at = soonest.addingTimeInterval(MeetingReminderPlanner.lateWindow + 1)
            if at > now, reminderTimer == nil || reminderTimer!.fireDate > at {
                reminderTimer?.invalidate()
                reminderTimer = Timer.scheduledTimer(withTimeInterval: at.timeIntervalSince(now), repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.planReminders() }
                }
            }
        }
        refresh()
    }

    // MARK: engine

    func submit(_ item: InboxItem, preset: AttentionLevel? = nil) {
        Task {
            do {
                guard let d = try await engine.evaluate(item, preset: preset) else { return }
                await handle(d)
            } catch {
                DiagnosticsLog.write("engine: evaluate \(item.kind.rawValue) failed: \(error.localizedDescription)")
            }
        }
    }

    func handle(_ d: Decision) async {
        switch d.outcome {
        case .shown:
            // FR-9: gist is written on arrival so the card opens instantly.
            gistByDecision[d.id] = await gists.gist(for: d.item)
            // T-1 replaces the T-5 card for the same meeting (ADR-025).
            if d.item.kind == .meeting, d.finalLevel == .interrupt, let start = d.item.startsAt {
                let earlier = waiting.filter { $0.item.kind == .meeting && $0.item.startsAt == start && $0.item.subject == d.item.subject }
                if let a = active, earlier.contains(where: { $0.id == a.id }) { envelope.close(); resolveActive(.opened) }
                waiting.removeAll { e in earlier.contains { $0.id == e.id } }
            }
            waiting.append(d)
            if wanderer?.place == .perched || wanderer?.place == .jumping { wanderer.leavePerch() }
            // Louder first; among equals, a risky approval, then needs you, then finished, then an error (ADR-024).
            waiting.sort {
                ($0.finalLevel ?? .ambient, AgentSessionTracker.rank($0.item), $1.at)
                    > ($1.finalLevel ?? .ambient, AgentSessionTracker.rank($1.item), $0.at)
            }
            if waiting.first?.id == d.id { armIgnoreTimer() }
            agentArrived(d)
        case .ambient:
            if d.item.kind == .mail { ambientPile += 1 }
        case .queued, .dropped:
            break
        }
        refresh()
    }

    func focusChanged(_ f: UserFocus) {
        // Locked, paused or in a call: Hush is off screen, so stop following the pointer and sensing (ADR-022).
        let offScreen = f.locked || f.paused || f.inCall
        antics.setSuspended(offScreen)
        if offScreen {
            pointerTimer?.invalidate()
            pointerTimer = nil
            watchPointerClosely(false)
        } else if pointerTimer == nil {
            schedulePointerTimer(fast: false)
        }
        onRefresh?()
        // The mic came on near a meeting: you joined. Its reminder has done its job (ADR-025).
        if f.inCall { meetingJoined() }
        // Natural breaks for the mail digest: back from 10+ minutes away, or a call ending (ADR-027).
        if !f.away, let since = awayStartedAt, Date().timeIntervalSince(since) >= 10 * 60 { maybeMailDigest() }
        if !f.inCall && wasInCall { maybeMailDigest() }
        awayStartedAt = f.away ? (awayStartedAt ?? Date()) : nil
        wasInCall = f.inCall
        antics.focusChanged(f)
        digest?.focusChanged(away: f.away)
        Task {
            do {
                let released = try await engine.setFocus(f)
                for d in released { await handle(d) }
            } catch {
                DiagnosticsLog.write("engine: releasing queued items failed: \(error.localizedDescription)")
            }
            refresh()
        }
    }

    func armIgnoreTimer() {
        ignoreTimer?.invalidate()
        guard let a = active else { return }
        resetMood()
        // An agent waiting on your OK stays until you answer; the card clears itself when you do (ADR-024).
        if AgentSessionTracker.waitsForAnswer(a.item) { return }
        // A meeting about to start stays until you join, snooze or dismiss it, or it's over (ADR-025).
        if a.item.kind == .meeting && a.finalLevel == .interrupt { return }
        let timeout = a.finalLevel == .interrupt ? Self.interruptTimeout
            : (moodsEnabled && a.item.kind == .mail ? Self.moodsTimeout : Self.gentleTimeout)
        ignoreTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.resolveActive(.ignored) }
        }
    }

    /// Log the user's response to the current appearance and move on to the next one.
    func resolveActive(_ response: UserResponse) {
        guard let a = active else { return }
        waiting.removeFirst()
        gistByDecision[a.id] = nil
        Task { try? await engine.record(response, for: a) }
        armIgnoreTimer()
        refresh()
    }

    // MARK: gestures
}
