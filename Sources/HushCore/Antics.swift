import Foundation

/// Playful moments (PRD § Delight). None of these are logged as decisions or count toward the interrupt cap.
public enum Antic: String, Sendable, CaseIterable {
    // Reactions to something the user just did. "Invited", so they may play any time Hush is visible.
    case cheeks          // copied something
    case screenshot      // took a screenshot
    case dizzy           // shook the cursor
    case flinch          // dragged a window past it
    case perk            // plugged in the charger

    // Unprompted. These only play when the user isn't busy and nothing real is waiting.
    case patRequest      // hasn't been touched in a while
    case morningStretch  // first activity after a long break
    case fridayDance     // Friday evening
    case tuckIn          // end of day: the held-back count

    public var isUnprompted: Bool {
        switch self {
        case .patRequest, .morningStretch, .fridayDance, .tuckIn: true
        default: false
        }
    }
}

/// What the policy needs to know. Plain data so the rules are testable.
public struct AnticContext: Sendable {
    public var now: Date
    public var focus: UserFocus
    /// A gentle/interrupt appearance is waiting for the user. Play never competes with it.
    public var hasActiveAppearance: Bool
    /// Last click, pat or drag on Hush.
    public var lastTouched: Date
    public var lastPatRequest: Date?
    public var patRequestsToday: Int
    public var lastTuckIn: Date?
    public var lastFridayDance: Date?

    public init(now: Date, focus: UserFocus = .idle, hasActiveAppearance: Bool = false, lastTouched: Date,
                lastPatRequest: Date? = nil, patRequestsToday: Int = 0, lastTuckIn: Date? = nil,
                lastFridayDance: Date? = nil) {
        self.now = now
        self.focus = focus
        self.hasActiveAppearance = hasActiveAppearance
        self.lastTouched = lastTouched
        self.lastPatRequest = lastPatRequest
        self.patRequestsToday = patRequestsToday
        self.lastTuckIn = lastTuckIn
        self.lastFridayDance = lastFridayDance
    }
}

/// When antics may play. The rule of thumb from the PRD: "every delight is either tiny or invited,
/// and nothing playful ever interrupts".
public struct AnticPolicy: Sendable {
    public var patRequestAfter: TimeInterval = 30 * 60
    public var maxPatRequestsPerDay = 3
    /// End of the working day, for the tuck-in. Minutes since midnight.
    public var tuckInMinute = 18 * 60 + 30
    /// A break this long counts as "a new morning" for the stretch.
    public var morningAfterAway: TimeInterval = 3 * 60 * 60
    public var calendar: Calendar

    public init(calendar: Calendar = .current) { self.calendar = calendar }

    /// Can anything play right now?
    public func mayPlay(_ a: Antic, _ c: AnticContext) -> Bool {
        if c.focus.hidesCharacter { return false }
        guard a.isUnprompted else { return true }
        return !c.focus.isBusy && !c.focus.away && !c.hasActiveAppearance
    }

    public func shouldRequestPat(_ c: AnticContext) -> Bool {
        guard mayPlay(.patRequest, c), c.patRequestsToday < maxPatRequestsPerDay else { return false }
        guard c.now.timeIntervalSince(c.lastTouched) >= patRequestAfter else { return false }
        if let last = c.lastPatRequest, c.now.timeIntervalSince(last) < patRequestAfter { return false }
        return true
    }

    /// Once a day, after the end-of-day time.
    public func shouldTuckIn(_ c: AnticContext) -> Bool {
        guard mayPlay(.tuckIn, c), minuteOfDay(c.now) >= tuckInMinute else { return false }
        if let last = c.lastTuckIn, calendar.isDate(last, inSameDayAs: c.now) { return false }
        return true
    }

    /// Friday from 18:00, once.
    public func shouldDance(_ c: AnticContext) -> Bool {
        guard mayPlay(.fridayDance, c), calendar.component(.weekday, from: c.now) == 6,
              minuteOfDay(c.now) >= 18 * 60 else { return false }
        if let last = c.lastFridayDance, calendar.isDate(last, inSameDayAs: c.now) { return false }
        return true
    }

    /// Coming back from a long break, or the first activity of a new day.
    public func isMorning(returningAt now: Date, awaySince: Date) -> Bool {
        now.timeIntervalSince(awaySince) >= morningAfterAway || !calendar.isDate(now, inSameDayAs: awaySince)
    }

    /// Late at night: yawns come more often.
    public func isLate(_ now: Date) -> Bool {
        let m = minuteOfDay(now)
        return m >= 23 * 60 || m < 5 * 60
    }

    private func minuteOfDay(_ d: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

/// Spots a cursor "shake" (fast back-and-forth, the way you'd shake to find the pointer) from pointer samples.
public struct ShakeDetector: Sendable {
    /// Direction reversals needed inside `window`.
    public var reversals = 4
    public var window: TimeInterval = 0.9
    /// Each leg must cover at least this many points, so slow wandering never counts.
    public var minLeg: Double = 60

    private var lastX: Double?
    private var direction = 0
    private var legStart: Double = 0
    private var turns: [TimeInterval] = []

    public init() {}

    /// Feed one sample; returns true when a shake completes.
    public mutating func add(x: Double, at t: TimeInterval) -> Bool {
        defer { lastX = x }
        guard let last = lastX, x != last else { return false }
        let dir = x > last ? 1 : -1
        if direction == 0 { direction = dir; legStart = last; return false }
        guard dir != direction else { return false }
        // Reversal: count it only if the leg was long enough.
        if abs(last - legStart) >= minLeg { turns.append(t) }
        direction = dir
        legStart = last
        turns.removeAll { t - $0 > window }
        if turns.count >= reversals {
            turns.removeAll()
            return true
        }
        return false
    }
}
