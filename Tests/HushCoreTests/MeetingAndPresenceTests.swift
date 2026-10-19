import Foundation
import Testing
@testable import HushCore

@Suite struct MeetingPlanner {
    let s = HushSettings()

    func meeting(inMinutes m: Double, allDay: Bool = false) -> Meeting {
        Meeting(id: "m", title: "Design review", start: tenAM.addingTimeInterval(m * 60),
                end: tenAM.addingTimeInterval((m + 30) * 60), isAllDay: allDay)
    }

    @Test func tenAndTwoMinuteReminders() {
        let r = MeetingReminderPlanner.reminders(for: [meeting(inMinutes: 30)], settings: s, now: tenAM)
        #expect(r.map(\.level) == [.gentle, .interrupt])
        #expect(r[0].fireAt == tenAM.addingTimeInterval(20 * 60))
        #expect(r[1].fireAt == tenAM.addingTimeInterval(28 * 60))
    }

    @Test func insideGentleWindowFiresNow() {
        let r = MeetingReminderPlanner.reminders(for: [meeting(inMinutes: 5)], settings: s, now: tenAM)
        #expect(r.first?.level == .gentle)
        #expect(r.first?.fireAt == tenAM)
    }

    @Test func insideInterruptWindowSkipsGentle() {
        let r = MeetingReminderPlanner.reminders(for: [meeting(inMinutes: 1)], settings: s, now: tenAM)
        #expect(r.map(\.level) == [.interrupt])
    }

    @Test func allDayAndPastMeetingsIgnored() {
        let r = MeetingReminderPlanner.reminders(
            for: [meeting(inMinutes: 30, allDay: true), meeting(inMinutes: -5)], settings: s, now: tenAM)
        #expect(r.isEmpty)
    }

    @Test func reminderIdsAreStable() {
        let a = MeetingReminderPlanner.reminders(for: [meeting(inMinutes: 30)], settings: s, now: tenAM)
        let b = MeetingReminderPlanner.reminders(for: [meeting(inMinutes: 30)], settings: s, now: tenAM.addingTimeInterval(60))
        #expect(a.map(\.item.id) == b.map(\.item.id))
    }
}

@Suite struct PresenceMapping {
    func shown(_ level: AttentionLevel, _ kind: ItemKind) -> Decision {
        let item = kind == .mail ? mail("x") : InboxItem(id: "m", kind: .meeting, subject: "Standup", receivedAt: tenAM)
        return Decision(id: "d", at: tenAM, item: item, proposedLevel: level, finalLevel: level,
                        outcome: .shown, confidence: 1, modelVersion: nil, reasons: [])
    }

    @Test func ladder() {
        #expect(Presence.state(for: .init(now: tenAM)) == .peek)
        #expect(Presence.state(for: .init(nextMeetingStart: tenAM.addingTimeInterval(7200), now: tenAM)) == .peek)
        #expect(Presence.state(for: .init(ambientPile: 3, now: tenAM)) == .pile)
        #expect(Presence.state(for: .init(active: shown(.gentle, .mail), now: tenAM)) == .hold)
        #expect(Presence.state(for: .init(active: shown(.gentle, .meeting), now: tenAM)) == .clock)
        #expect(Presence.state(for: .init(active: shown(.interrupt, .mail), now: tenAM)) == .hurry)
    }

    @Test func dozesOnlyWhileAwayWithNothingSoon() {
        let away = UserFocus(away: true)
        #expect(Presence.state(for: .init(focus: away, now: tenAM)) == .doze)
        #expect(Presence.state(for: .init(focus: away, nextMeetingStart: tenAM.addingTimeInterval(600), now: tenAM)) == .peek)
        #expect(Presence.state(for: .init(focus: away, ambientPile: 5, now: tenAM)) == .pile)
    }

    @Test func hidingBeatsEverythingButBow() {
        let busy = UserFocus(inCall: true)
        #expect(Presence.state(for: .init(focus: busy, active: shown(.interrupt, .mail), now: tenAM)) == .hide)
        #expect(Presence.state(for: .init(focus: busy, now: tenAM, justShooed: true)) == .bow)
    }

    @Test func typingDucksButStaysVisible() {
        let typing = UserFocus(typing: true)
        #expect(Presence.state(for: .init(focus: typing, ambientPile: 4, now: tenAM)) == .hide)
        #expect(!typing.hidesCharacter)
    }
}
