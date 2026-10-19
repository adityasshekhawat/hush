import Foundation

public struct Meeting: Sendable, Equatable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var attendees: [String]
    public var openURL: URL?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
                attendees: [String] = [], openURL: URL? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.attendees = attendees
        self.openURL = openURL
    }
}

public struct MeetingReminder: Sendable, Equatable {
    public var meeting: Meeting
    public var level: AttentionLevel
    public var fireAt: Date

    /// The item handed to the engine. The id is stable per meeting + level, so re-planning never double-fires.
    public var item: InboxItem {
        InboxItem(
            id: "meeting:\(meeting.id):\(meeting.start.timeIntervalSince1970):\(level.name)",
            kind: .meeting, subject: meeting.title,
            snippet: meeting.attendees.prefix(4).joined(separator: ", "),
            receivedAt: fireAt, startsAt: meeting.start, openURL: meeting.openURL)
    }
}

/// FR-6: meeting reminders are computed in code from start times, never by a model.
public enum MeetingReminderPlanner {
    /// All reminders still relevant at `now`, soonest first. A reminder whose time has passed but whose
    /// meeting hasn't started (and whose louder successor isn't due yet) fires immediately.
    public static func reminders(for meetings: [Meeting], settings: HushSettings, now: Date) -> [MeetingReminder] {
        var out: [MeetingReminder] = []
        for m in meetings where !m.isAllDay && m.start > now {
            let gentleAt = m.start.addingTimeInterval(-settings.gentleMeetingLead)
            let interruptAt = m.start.addingTimeInterval(-settings.interruptMeetingLead)
            if interruptAt > now {
                out.append(MeetingReminder(meeting: m, level: .gentle, fireAt: max(gentleAt, now)))
            }
            out.append(MeetingReminder(meeting: m, level: .interrupt, fireAt: max(interruptAt, now)))
        }
        return out.sorted { $0.fireAt < $1.fireAt }
    }

    /// Next meeting start after `now` (for the doze vs peek decision).
    public static func nextStart(in meetings: [Meeting], after now: Date) -> Date? {
        meetings.filter { !$0.isAllDay && $0.start > now }.map(\.start).min()
    }
}
