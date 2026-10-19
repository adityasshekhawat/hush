import Foundation
import Testing
@testable import HushCore

@Suite struct MeetingLinkFinding {
    @Test func findsTheCallWhereverItIs() {
        #expect(MeetingLinks.joinURL(url: URL(string: "https://acme.zoom.us/j/123456789?pwd=abc"), location: nil, notes: nil)?
            .absoluteString == "https://acme.zoom.us/j/123456789?pwd=abc")
        #expect(MeetingLinks.joinURL(url: nil, location: "https://meet.google.com/abc-defg-hij", notes: nil)?
            .absoluteString == "https://meet.google.com/abc-defg-hij")
        let teams = "Join: https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=x\nMeeting ID: 1"
        #expect(MeetingLinks.joinURL(url: nil, location: "Room 4", notes: teams)?.host == "teams.microsoft.com")
        // Trailing punctuation from prose isn't part of the link.
        #expect(MeetingLinks.joinURL(url: nil, location: nil, notes: "Call at https://whereby.com/acme-team.")?
            .absoluteString == "https://whereby.com/acme-team")
    }

    @Test func ignoresLinksThatArentCalls() {
        #expect(MeetingLinks.joinURL(url: URL(string: "https://docs.google.com/document/d/1"), location: "HQ",
                                     notes: "Agenda: https://notion.so/plan") == nil)
        // The event URL wins over a call link that's only mentioned in the notes.
        #expect(MeetingLinks.joinURL(url: URL(string: "https://zoom.us/j/1"), location: nil,
                                     notes: "old link https://meet.google.com/aaa-bbbb-ccc")?.host == "zoom.us")
    }

    @Test func notesKeepWordsAndDropBoilerplate() {
        let notes = """
            Q4 roadmap: bring the hiring plan.
            https://zoom.us/j/1
            Meeting ID: 123 456
            Passcode: 999
            ─────────
            """
        #expect(MeetingLinks.trimNotes(notes) == "Q4 roadmap: bring the hiring plan.")
        #expect(MeetingLinks.trimNotes("Dial in: +1 555") == nil)
        #expect(MeetingLinks.trimNotes(nil) == nil)
    }

    @Test func whoIsShort() {
        func m(_ a: [String]) -> Meeting { Meeting(id: "m", title: "t", start: tenAM, end: tenAM, attendees: a) }
        #expect(m(["Priya", "Sam", "Dana", "Lee"]).who == "Priya + 3")
        #expect(m(["Priya"]).who == "Priya")
        #expect(m([]).who == "")
    }

    @Test func remindersCarryTheCall() {
        let m = Meeting(id: "m", title: "Design review", start: tenAM.addingTimeInterval(600), end: tenAM.addingTimeInterval(2400),
                        attendees: ["Priya", "Sam"], openURL: URL(string: "ical://x"), joinURL: URL(string: "https://zoom.us/j/1"),
                        notes: "Bring the deck")
        let item = MeetingReminderPlanner.reminders(for: [m], settings: HushSettings(), now: tenAM)[0].item
        #expect(item.openURL?.absoluteString == "https://zoom.us/j/1")
        #expect(item.snippet == "Priya + 1")
        #expect(item.notes == "Bring the deck")
    }

    @Test func aStartedMeetingStaysForTheLateWindow() {
        let item = InboxItem(id: "meeting:m", kind: .meeting, subject: "x", receivedAt: tenAM, startsAt: tenAM)
        #expect(!MeetingReminderPlanner.isOver(item, now: tenAM.addingTimeInterval(4 * 60)))
        #expect(MeetingReminderPlanner.isOver(item, now: tenAM.addingTimeInterval(5 * 60)))
    }

    @Test func oldDefaultsMoveToTheNewOnes() {
        var old = HushSettings(gentleMeetingLead: 600, interruptMeetingLead: 120)
        old.migrateMeetingLeads()
        #expect(old.gentleMeetingLead == 300 && old.interruptMeetingLead == 60)
        var mine = HushSettings(gentleMeetingLead: 900, interruptMeetingLead: 120)
        mine.migrateMeetingLeads()
        #expect(mine.gentleMeetingLead == 900)
    }
}
