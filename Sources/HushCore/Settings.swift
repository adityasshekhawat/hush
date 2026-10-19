import Foundation

/// Quiet hours as minutes since local midnight. Wraps past midnight when start > end (e.g. 22:00–07:00).
public struct QuietHours: Sendable, Equatable, Codable {
    public var startMinute: Int
    public var endMinute: Int

    public init(start: (hour: Int, minute: Int), end: (hour: Int, minute: Int)) {
        startMinute = start.hour * 60 + start.minute
        endMinute = end.hour * 60 + end.minute
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if startMinute == endMinute { return false }
        return startMinute < endMinute
            ? (m >= startMinute && m < endMinute)
            : (m >= startMinute || m < endMinute)
    }
}

public struct HushSettings: Sendable, Equatable, Codable {
    /// FR-8: max interrupts per day.
    public var maxInterruptsPerDay: Int
    public var quietHours: QuietHours?
    /// Lowercased addresses or "@domain.com" entries. Only VIPs and user rules can interrupt (FR-5).
    public var vips: Set<String>
    /// Below this, a classification counts as unsure and resolves to gentle at most (FR-5).
    public var confidenceThreshold: Double
    /// FR-11: shoos of one type before that type is lowered.
    public var shoosToLower: Int
    /// FR-6: reminder offsets.
    public var gentleMeetingLead: TimeInterval
    public var interruptMeetingLead: TimeInterval

    public init(
        maxInterruptsPerDay: Int = 5,
        quietHours: QuietHours? = nil,
        vips: Set<String> = [],
        confidenceThreshold: Double = 0.7,
        shoosToLower: Int = 3,
        gentleMeetingLead: TimeInterval = 5 * 60,
        interruptMeetingLead: TimeInterval = 1 * 60
    ) {
        self.maxInterruptsPerDay = maxInterruptsPerDay
        self.quietHours = quietHours
        self.vips = Set(vips.map { $0.lowercased() })
        self.confidenceThreshold = confidenceThreshold
        self.shoosToLower = shoosToLower
        self.gentleMeetingLead = gentleMeetingLead
        self.interruptMeetingLead = interruptMeetingLead
    }

    /// The v1 timings are T-5 / T-1 (ADR-021, ADR-025). Settings saved with the old untouched defaults (10 / 2) move
    /// to the new ones; anything you chose yourself stays.
    public mutating func migrateMeetingLeads() {
        if gentleMeetingLead == 10 * 60 && interruptMeetingLead == 2 * 60 {
            gentleMeetingLead = 5 * 60
            interruptMeetingLead = 1 * 60
        }
    }

    public func isVIP(_ item: InboxItem) -> Bool {
        guard let address = item.senderAddress else { return false }
        if vips.contains(address) { return true }
        if let domain = item.senderDomain, vips.contains("@" + domain) { return true }
        return false
    }
}

/// A confirmed rule. Rules run in code and bypass the model (PRD § Learning: "Rules run in code, not in a prompt").
public struct UserRule: Sendable, Equatable, Codable, Identifiable {
    public enum Match: Sendable, Equatable, Codable {
        case sender(String)
        case senderDomain(String)
        case category(String)
    }

    public enum Action: String, Sendable, Codable {
        /// "Not this kind again": drop silently.
        case never
        /// Always surface at this level (the only non-VIP path to interrupt).
        case alwaysGentle
        case alwaysInterrupt
    }

    public var id: String
    public var match: Match
    public var action: Action
    public var createdAt: Date

    public init(id: String = UUID().uuidString, match: Match, action: Action, createdAt: Date = Date()) {
        self.id = id
        self.match = match
        self.action = action
        self.createdAt = createdAt
    }

    public func matches(_ item: InboxItem) -> Bool {
        switch match {
        case .sender(let s): item.senderAddress == s.lowercased()
        case .senderDomain(let d): item.senderDomain == d.lowercased()
        case .category(let c): item.category == c
        }
    }
}
