import Foundation

/// Rare finds (docs/design-guide.md §6b): 14 pieces Hush wears on its own, very rarely. Silent (no card, no sound,
/// no glyph change), local, at most one find a day, never while you're busy or something waits. Found pieces become
/// wearable any day; unfound ones show as silhouettes with a vague hint once another piece of their tier is found.
public enum RareTier: String, Sendable, CaseIterable, Codable {
    case lucky, seasonal, milestone
}

public struct RareFind: Sendable, Equatable, Identifiable {
    public var id: String
    /// "a little bird" (the panel line reads "New find: a little bird").
    public var phrase: String
    public var tier: RareTier
    /// Half a sentence; never the exact rule.
    public var hint: String
}

/// Moments a roll can happen (once per eligible moment, on the Mac).
public enum RareMoment: Sendable, Equatable {
    case morning            // quiet morning before 10:00 with nothing waiting (once a day)
    case afternoon          // after lunch (once a day)
    case springDay          // a spring day (once a day)
    case lateNight          // working past 01:00 (once a night)
    case drag               // every drag
    case firstUnlock(daysAway: Double, weekday: Int, hour: Int)
    case askCount(Int)      // total Ask Hush questions so far
    case quietWeek          // a full week with zero interrupts needed
    case dayStart           // the first check of a day: dated finds
}

/// What's been found and what Hush wears today. Saved as JSON.
public struct RareState: Sendable, Equatable, Codable {
    /// Piece id → when it was first found.
    public var found: [String: Date] = [:]
    /// Worn now, and when it leaves.
    public var wearing: [String: Date] = [:]
    /// The day of the last find (daily cap) and the line for the panel.
    public var lastFindDay: Date?
    public var lastFindPhrase: String?
    /// Moment key → the day it last rolled (once per eligible moment).
    public var rolled: [String: Date] = [:]
    public init() {}
}

public struct RareContext: Sendable {
    public var now: Date
    public var calendar: Calendar
    /// On a call, full screen, typing focus, quiet hours, or something waiting: no rolls.
    public var busy: Bool
    public var installDate: Date
    public var southernHemisphere: Bool

    public init(now: Date, calendar: Calendar = .current, busy: Bool, installDate: Date, southernHemisphere: Bool = false) {
        self.now = now
        self.calendar = calendar
        self.busy = busy
        self.installDate = installDate
        self.southernHemisphere = southernHemisphere
    }
}

public enum RareFinds {
    public static let all: [RareFind] = [
        .init(id: "bird", phrase: "a little bird", tier: .lucky, hint: "Quiet mornings"),
        .init(id: "snail", phrase: "a slow snail", tier: .lucky, hint: "After lunch"),
        .init(id: "butterfly", phrase: "a butterfly", tier: .lucky, hint: "Something about spring"),
        .init(id: "propellerCap", phrase: "a propeller cap", tier: .lucky, hint: "Being carried around"),
        .init(id: "cocoa", phrase: "a cup of cocoa", tier: .lucky, hint: "Early Mondays"),
        .init(id: "lantern", phrase: "a lantern", tier: .lucky, hint: "Late nights"),
        .init(id: "partyHat", phrase: "a party hat", tier: .seasonal, hint: "A special day"),
        .init(id: "balloon", phrase: "a balloon", tier: .seasonal, hint: "A special day"),
        .init(id: "flowerCrown", phrase: "a flower crown", tier: .seasonal, hint: "The first warm day"),
        .init(id: "heartGlasses", phrase: "heart glasses", tier: .seasonal, hint: "Mid-February"),
        .init(id: "bell", phrase: "a jingle bell", tier: .seasonal, hint: "The end of the year"),
        .init(id: "halo", phrase: "a halo", tier: .milestone, hint: "A very quiet week"),
        .init(id: "lei", phrase: "a welcome lei", tier: .milestone, hint: "Coming back"),
        .init(id: "monocle", phrase: "a monocle", tier: .milestone, hint: "Lots of questions"),
    ]

    public static func find(_ id: String) -> RareFind? { all.first { $0.id == id } }

    /// Lucky odds (1 in n per eligible moment).
    static let odds: [String: Int] = ["bird": 300, "snail": 400, "butterfly": 250, "propellerCap": 500, "cocoa": 20, "lantern": 50]

    // MARK: rolling

    /// Pieces found at this moment (empty most of the time). Updates `state`: found, wearing, the daily cap.
    public static func roll(_ moment: RareMoment, state: inout RareState, ctx: RareContext,
                            random: () -> Double = { Double.random(in: 0..<1) }) -> [String] {
        let cal = ctx.calendar
        let today = cal.startOfDay(for: ctx.now)
        if let last = state.lastFindDay, cal.isDate(last, inSameDayAs: ctx.now) { return [] }   // 1 a day
        if ctx.busy, moment != .dayStart { return [] }

        let key: String? = switch moment {
        case .morning: "morning"
        case .afternoon: "afternoon"
        case .springDay: "spring"
        case .lateNight: "late"
        case .dayStart: "day"
        case .quietWeek: "week"
        case .firstUnlock: "unlock"
        case .drag, .askCount: nil
        }
        if let key {
            if let r = state.rolled[key], cal.isDate(r, inSameDayAs: ctx.now) { return [] }
            state.rolled[key] = today
        }

        var won: [String] = []
        switch moment {
        case .dayStart:
            won = dated(ctx)   // dated finds win over lucky rolls that day
        case .morning:
            if cal.component(.hour, from: ctx.now) < 10 { won = lucky("bird", random) }
        case .afternoon:
            let h = cal.component(.hour, from: ctx.now)
            if (13..<17).contains(h) { won = lucky("snail", random) }
        case .springDay:
            if isSpring(ctx) { won = lucky("butterfly", random) }
        case .lateNight:
            let h = cal.component(.hour, from: ctx.now)
            if (1..<5).contains(h) { won = lucky("lantern", random) }
        case .drag:
            won = lucky("propellerCap", random)
        case .firstUnlock(let away, let weekday, let hour):
            if away >= 5 { won = ["lei"] }
            else if weekday == 2 && hour < 8 { won = lucky("cocoa", random) }
        case .askCount(let n):
            if n == 100, state.found["monocle"] == nil { won = ["monocle"] }
        case .quietWeek:
            won = ["halo"]
        }
        guard !won.isEmpty else { return [] }
        for id in won {
            if state.found[id] == nil { state.found[id] = ctx.now }
            state.wearing[id] = leavesAt(id, from: ctx.now, calendar: cal)
        }
        state.lastFindDay = today
        state.lastFindPhrase = won.compactMap { find($0)?.phrase }.joined(separator: " and ")
        return won
    }

    static func lucky(_ id: String, _ random: () -> Double) -> [String] {
        guard let n = odds[id] else { return [] }
        return random() < 1 / Double(n) ? [id] : []
    }

    /// Birthday (the install date), the first day of spring, 14 February, the last week of December.
    static func dated(_ ctx: RareContext) -> [String] {
        let cal = ctx.calendar
        let d = cal.dateComponents([.month, .day, .year], from: ctx.now)
        let born = cal.dateComponents([.month, .day, .year], from: ctx.installDate)
        if d.month == born.month && d.day == born.day && d.year != born.year { return ["partyHat", "balloon"] }
        let springStart = ctx.southernHemisphere ? (9, 1) : (3, 20)
        if d.month == springStart.0 && d.day == springStart.1 { return ["flowerCrown"] }
        if d.month == 2 && d.day == 14 { return ["heartGlasses"] }
        if d.month == 12, let day = d.day, day >= 25 { return ["bell"] }
        return []
    }

    static func isSpring(_ ctx: RareContext) -> Bool {
        let m = ctx.calendar.component(.month, from: ctx.now)
        return ctx.southernHemisphere ? (9...11).contains(m) : (3...5).contains(m)
    }

    /// When each piece leaves (most at midnight).
    public static func leavesAt(_ id: String, from now: Date, calendar cal: Calendar) -> Date {
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        switch id {
        case "bird": return min(midnight, cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? midnight)
        case "snail": return now.addingTimeInterval(10 * 60)
        case "butterfly": return now.addingTimeInterval(3 * 60)
        case "lantern": return cal.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? midnight
        case "monocle": return now.addingTimeInterval(3 * 60)
        default: return midnight
        }
    }

    /// Drop pieces whose time is up. The bird also leaves when Hush is dragged.
    public static func expire(_ state: inout RareState, now: Date, dragged: Bool = false) -> [String] {
        let gone = state.wearing.filter { $0.value <= now || (dragged && $0.key == "bird") }.map(\.key)
        gone.forEach { state.wearing[$0] = nil }
        return gone
    }

    /// The muted panel line, only on the day of the find.
    public static func panelLine(_ state: RareState, now: Date, calendar: Calendar = .current) -> String? {
        guard let d = state.lastFindDay, calendar.isDate(d, inSameDayAs: now), let p = state.lastFindPhrase else { return nil }
        return "New find: \(p)"
    }

    /// A hint shows only once another piece of the same tier has been found.
    public static func showsHint(_ f: RareFind, state: RareState) -> Bool {
        all.contains { $0.tier == f.tier && $0.id != f.id && state.found[$0.id] != nil }
    }
}
