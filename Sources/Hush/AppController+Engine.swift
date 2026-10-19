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
        // Drop meeting appearances whose meeting has started.
        waiting.removeAll { $0.item.kind == .meeting && ($0.item.startsAt ?? .distantFuture) <= now }
        refresh()
    }

    // MARK: engine

    func submit(_ item: InboxItem, preset: AttentionLevel? = nil) {
        Task {
            guard let d = try await engine.evaluate(item, preset: preset) else { return }
            await handle(d)
        }
    }

    func handle(_ d: Decision) async {
        switch d.outcome {
        case .shown:
            // FR-9: gist is written on arrival so the card opens instantly.
            gistByDecision[d.id] = await gists.gist(for: d.item)
            waiting.append(d)
            if wanderer?.place == .perched || wanderer?.place == .jumping { wanderer.leavePerch() }
            waiting.sort { ($0.finalLevel ?? .ambient, $1.at) > ($1.finalLevel ?? .ambient, $0.at) }
            if waiting.first?.id == d.id { armIgnoreTimer() }
        case .ambient:
            if d.item.kind == .mail { ambientPile += 1 }
        case .queued, .dropped:
            break
        }
        refresh()
    }

    func focusChanged(_ f: UserFocus) {
        antics.focusChanged(f)
        digest?.focusChanged(away: f.away)
        Task {
            let released = try await engine.setFocus(f)
            for d in released { await handle(d) }
            refresh()
        }
    }

    func armIgnoreTimer() {
        ignoreTimer?.invalidate()
        guard let a = active else { return }
        resetMood()
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
