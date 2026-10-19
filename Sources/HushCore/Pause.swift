import Foundation

/// Pausing Hush (ADR-022): one action takes it off the screen; anything that arrives meanwhile queues and shows when the
/// pause ends (a meeting that has already started is dropped as stale, like after a call).
public enum PauseLength: String, CaseIterable, Sendable {
    case quarterHour, hour, untilTomorrow

    public var title: String {
        switch self {
        case .quarterHour: "15 minutes"
        case .hour: "1 hour"
        case .untilTomorrow: "Until tomorrow"
        }
    }

    /// "Until tomorrow" ends at 08:00 the next morning (in the small hours, that's this morning).
    public static let morningHour = 8

    public func until(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .quarterHour: return now.addingTimeInterval(15 * 60)
        case .hour: return now.addingTimeInterval(60 * 60)
        case .untilTomorrow:
            let thisMorning = calendar.date(bySettingHour: Self.morningHour, minute: 0, second: 0, of: now)!
            return thisMorning > now ? thisMorning : calendar.date(byAdding: .day, value: 1, to: thisMorning)!
        }
    }
}

public enum PauseText {
    /// "Paused until 15:30" / "Paused until tomorrow, 08:00", for the menu bar panel and the bubble.
    public static func status(until end: Date, now: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        let time = f.string(from: end)
        return calendar.isDate(end, inSameDayAs: now) ? "Paused until \(time)" : "Paused until tomorrow, \(time)"
    }
}
