import Foundation

public struct Meeting: Sendable, Equatable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var attendees: [String]
    /// Opens the event in Calendar.
    public var openURL: URL?
    /// The video call, when the invite has one (ADR-025): one click on Hush joins.
    public var joinURL: URL?
    /// The invite's notes, trimmed (MeetingLinks.trimNotes), for the context line.
    public var notes: String?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
                attendees: [String] = [], openURL: URL? = nil, joinURL: URL? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.attendees = attendees
        self.openURL = openURL
        self.joinURL = joinURL
        self.notes = notes
    }

    /// "Priya + 3": who's coming, short enough for a card (the spec's "Q4 roadmap · Priya + 3").
    public var who: String {
        guard let first = attendees.first else { return "" }
        return attendees.count == 1 ? first : "\(first) + \(attendees.count - 1)"
    }
}

/// Finds the video-call link in an invite (ADR-025): the event URL, then the location, then the notes. Known
/// providers only, so a random link in the notes is never mistaken for the call.
public enum MeetingLinks {
    static let pattern = #"https://(?:[a-z0-9-]+\.)?(?:zoom\.us/(?:j|my|w|s)/[^\s<>"')]+|zoom\.us/meeting/[^\s<>"')]+|meet\.google\.com/[a-z]{3,4}-[a-z]{4}-[a-z]{3,4}[^\s<>"')]*|teams\.microsoft\.com/l/meetup-join/[^\s<>"')]+|teams\.live\.com/meet/[^\s<>"')]+|[a-z0-9-]+\.webex\.com/[^\s<>"')]+|whereby\.com/[^\s<>"')]+|around\.co/[^\s<>"')]+|facetime\.apple\.com/join[^\s<>"')]+|app\.slack\.com/huddle/[^\s<>"')]+|meet\.jit\.si/[^\s<>"')]+|app\.gather\.town/[^\s<>"')]+)"#

    public static func joinURL(url: URL?, location: String?, notes: String?) -> URL? {
        for text in [url?.absoluteString, location, notes].compactMap({ $0 }) {
            if let r = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                var link = String(text[r])
                while let last = link.last, ".,;:!?>".contains(last) { link.removeLast() }
                if let u = URL(string: link) { return u }
            }
        }
        return nil
    }

    /// Notes for the context line: the first 400 characters of text, links and dial-in boilerplate dropped.
    public static func trimNotes(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let lines = notes.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { l in
            !l.isEmpty && l.range(of: #"https?://"#, options: .regularExpression) == nil
                && l.range(of: #"(?i)(dial|meeting id|passcode|password|pin:|join (by|with|from)|one tap|─|—{3,}|-{3,}|_{3,})"#,
                           options: .regularExpression) == nil
        }
        let text = lines.joined(separator: " ")
        guard text.count >= 8 else { return nil }
        return text.count > 400 ? String(text.prefix(400)) : text
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
            snippet: meeting.who,
            receivedAt: fireAt, startsAt: meeting.start, openURL: meeting.joinURL ?? meeting.openURL,
            notes: meeting.notes)
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

    /// A started meeting's reminder stays this long ("running late"), unless you join (the mic turns on) first.
    public static let lateWindow: TimeInterval = 5 * 60

    /// Has this meeting reminder had its moment? Past the late window, it has.
    public static func isOver(_ item: InboxItem, now: Date) -> Bool {
        guard item.kind == .meeting, let start = item.startsAt else { return false }
        return now >= start.addingTimeInterval(lateWindow)
    }

    /// Next meeting start after `now` (for the doze vs peek decision).
    public static func nextStart(in meetings: [Meeting], after now: Date) -> Date? {
        meetings.filter { !$0.isAllDay && $0.start > now }.map(\.start).min()
    }
}
