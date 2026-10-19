import EventKit
import Foundation
import HushCore

/// Reads events from every account in the Calendar app (FR-1, FR-2). Reacts to EKEventStoreChanged; never polls.
@MainActor
public final class CalendarSource {
    public enum Access: Equatable { case granted, denied, notDetermined }

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    /// How far ahead to look. Reminders only need the next few hours; 24h keeps "doze vs peek" honest.
    public var horizon: TimeInterval = 24 * 60 * 60
    /// Called with the fresh meeting list on start and whenever the calendar changes.
    public var onChange: (([Meeting]) -> Void)?

    public init() {}

    public static var access: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Shows the system prompt. Needs a real .app bundle with NSCalendarsFullAccessUsageDescription;
    /// a bare `swift run` binary gets denied silently (see scripts/bundle.sh).
    public func requestAccess() async -> Bool {
        // Completion-handler form: the async overload would send the main-actor store across isolation.
        // EventKit calls back on its own queue, so the callback must not be main-actor isolated (Swift 6 traps
        // when it checks the executor). It only resumes the continuation, which is safe from any thread.
        await withCheckedContinuation { cont in
            store.requestFullAccessToEvents { @Sendable granted, _ in cont.resume(returning: granted) }
        }
    }

    public func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    public func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    public func reload() {
        onChange?(meetings())
    }

    public func meetings(from now: Date = Date()) -> [Meeting] {
        guard Self.access == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-60 * 60),
                                                 end: now.addingTimeInterval(horizon), calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled && !Self.declined($0) }
            .map { e in
                Meeting(
                    id: e.calendarItemIdentifier,
                    title: e.title ?? "Untitled event",
                    start: e.startDate,
                    end: e.endDate,
                    isAllDay: e.isAllDay,
                    attendees: (e.attendees ?? []).filter { !$0.isCurrentUser }.compactMap { $0.name },
                    openURL: URL(string: "ical://ekevent/\(e.calendarItemIdentifier)?method=show&options=more"))
            }
    }

    private static func declined(_ e: EKEvent) -> Bool {
        e.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined
    }
}
