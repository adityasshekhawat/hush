import Foundation

public enum UserResponse: String, Sendable, Codable {
    case opened
    case notThisKind
    case shooed
    case ignored
    /// Self-test tags (PRD § Success metrics).
    case worthIt
    case notWorthIt
}

/// One pass of an item through the cascade, as logged (FR-12).
public struct Decision: Sendable, Equatable {
    public enum Outcome: String, Sendable, Codable {
        /// Character stepped forward (gentle or interrupt).
        case shown
        /// Added to the ambient pile; counts as "held back".
        case ambient
        /// Would have shown, but the user is busy or it's quiet hours. Re-evaluated later.
        case queued
        /// Bulk mail or a "never" rule.
        case dropped
    }

    public var id: String
    public var at: Date
    public var item: InboxItem
    /// What the rules / model asked for, before caps and focus.
    public var proposedLevel: AttentionLevel?
    /// What the character actually does. nil when dropped.
    public var finalLevel: AttentionLevel?
    public var outcome: Outcome
    public var confidence: Double?
    public var modelVersion: String?
    /// Human-readable trail, e.g. ["VIP", "daily cap reached → gentle"].
    public var reasons: [String]
}

/// The cascade: rules → classifier → caps and focus. Owns the store.
public actor DecisionEngine {
    private let store: HushStore
    private let classifier: AttentionClassifier
    private let calendar: Calendar
    public private(set) var settings: HushSettings
    public private(set) var focus: UserFocus = .idle
    private var queue: [(item: InboxItem, preset: AttentionLevel?)] = []
    /// Item ids already decided, so re-planned meeting reminders or re-delivered mail don't double-fire.
    private var seen: Set<String> = []

    public init(store: HushStore, classifier: AttentionClassifier, settings: HushSettings = .init(), calendar: Calendar = .current) {
        self.store = store
        self.classifier = classifier
        self.settings = settings
        self.calendar = calendar
    }

    public func update(settings: HushSettings) { self.settings = settings }

    public var queuedCount: Int { queue.count }

    /// Run one item through the cascade. `preset` is for items whose level is computed in code
    /// (meeting reminders, FR-6). Returns nil for an item already decided.
    @discardableResult
    public func evaluate(_ item: InboxItem, preset: AttentionLevel? = nil, now: Date = Date()) async throws -> Decision? {
        guard !seen.contains(item.id) else { return nil }
        seen.insert(item.id)
        return try await decide(item, preset: preset, now: now)
    }

    private func decide(_ item: InboxItem, preset: AttentionLevel?, now: Date) async throws -> Decision {
        var reasons: [String] = []
        var d = Decision(id: UUID().uuidString, at: now, item: item, proposedLevel: nil, finalLevel: nil,
                         outcome: .dropped, confidence: nil, modelVersion: nil, reasons: [])

        // ---- Step 1: rules in code ----
        let rules = try store.rules()
        let rule = rules.first { $0.matches(item) }
        // Bulk mail is dropped, unless one of your rules asks for it (alerts often come from noreply@; ADR-027).
        let asked = rule?.action == .alwaysGentle || rule?.action == .alwaysInterrupt
        if BulkMailFilter.isBulk(item) && !asked {
            d.reasons = ["bulk headers"]
            try store.insert(d)
            return d
        }
        if rule?.action == .never {
            d.reasons = ["rule: not this kind again"]
            try store.insert(d)
            return d
        }

        var level: AttentionLevel
        var byRule = false
        if let preset {
            level = preset
            d.confidence = 1
            d.modelVersion = "code"
            reasons.append(item.kind == .meeting ? "meeting reminder" : "computed in code (\(item.kind.rawValue))")
        } else if let rule, rule.action == .alwaysInterrupt || rule.action == .alwaysGentle {
            level = rule.action == .alwaysInterrupt ? .interrupt : .gentle
            byRule = true
            d.confidence = 1
            d.modelVersion = "rule"
            reasons.append("rule: \(rule.action.rawValue)")
        } else if settings.isVIP(item) {
            level = .interrupt
            byRule = true
            d.confidence = 1
            d.modelVersion = "rule"
            reasons.append("VIP")
        } else {
            // ---- Step 2: classifier ----
            let c = await classifier.classify(item)
            level = c.level
            d.confidence = c.confidence
            d.modelVersion = c.modelVersion
            reasons.append("model: \(c.level.name) @ \(String(format: "%.2f", c.confidence))")
            // FR-5: only VIPs, rules and meeting times can interrupt.
            if level == .interrupt {
                level = .gentle
                reasons.append("model can't interrupt alone → gentle")
            }
            // FR-5 + Principle 2: unsure caps at gentle and never escalates. See docs/decisions.md ADR-003.
            // (Redundant today because interrupt is already capped above; kept so the rule survives if that changes.)
            if (c.confidence < settings.confidenceThreshold) && (level > .gentle) {
                level = .gentle
                reasons.append("low confidence → gentle")
            }
        }
        d.proposedLevel = level

        // FR-11: three shoos of a type lower it one rung. Explicit rules are left alone.
        if !byRule, level > .ambient, try store.shooCount(category: item.category) >= settings.shoosToLower {
            level = level.lowered
            reasons.append("shooed \(settings.shoosToLower)+ times → \(level.name)")
        }

        // ---- Gates: quiet hours, daily cap, focus ----
        if level > .ambient, let q = settings.quietHours, q.contains(now, calendar: calendar) {
            if item.kind == .meeting {
                // A reminder is useless later; keep it, but no louder than gentle.
                if level == .interrupt { level = .gentle; reasons.append("quiet hours → gentle") }
            } else {
                level = .ambient
                reasons.append("quiet hours → ambient")
            }
        }

        if level == .interrupt {
            let day = calendar.dateInterval(of: .day, for: now)!
            if try store.interruptsShown(from: day.start, to: day.end) >= settings.maxInterruptsPerDay {
                level = .gentle
                reasons.append("daily cap reached → gentle")
            }
        }

        d.finalLevel = level
        if level == .ambient {
            d.outcome = .ambient
        } else if focus.isBusy {
            d.outcome = .queued
            reasons.append("busy → queued")
            queue.append((item, preset))
        } else {
            d.outcome = .shown
        }

        d.reasons = reasons
        try store.insert(d)
        return d
    }

    /// FR-7: update focus. When the user frees up, queued items are re-evaluated and returned.
    /// Meeting reminders whose meeting has already started are dropped as stale.
    public func setFocus(_ f: UserFocus, now: Date = Date()) async throws -> [Decision] {
        focus = f
        guard !f.isBusy, !queue.isEmpty else { return [] }
        let pending = queue
        queue.removeAll()
        var out: [Decision] = []
        for (item, preset) in pending {
            if item.kind == .meeting, let start = item.startsAt, start <= now { continue }
            out.append(try await decide(item, preset: preset, now: now))
        }
        return out
    }

    // MARK: user responses (signals)

    public func record(_ response: UserResponse, for decision: Decision, now: Date = Date()) throws {
        try store.recordResponse(decisionID: decision.id, response, at: now)
        if response == .shooed {
            try store.addShoo(category: decision.item.category, at: now)
        }
    }

    /// "Not this kind again" (FR-10): a hard rule, created on the spot because the user asked for it explicitly.
    @discardableResult
    public func notThisKindAgain(_ decision: Decision, now: Date = Date()) throws -> UserRule {
        try store.recordResponse(decisionID: decision.id, .notThisKind, at: now)
        let match: UserRule.Match = decision.item.senderAddress.map { .sender($0) } ?? .category(decision.item.category)
        let rule = UserRule(match: match, action: .never, createdAt: now)
        try store.save(rule)
        return rule
    }

    public func addRule(_ rule: UserRule) throws { try store.save(rule) }
    public func deleteRule(id: String) throws { try store.deleteRule(id: id) }
    public func rules() throws -> [UserRule] { try store.rules() }

    public func daySummary(now: Date = Date()) throws -> DaySummary {
        let day = calendar.dateInterval(of: .day, for: now)!
        return try store.daySummary(from: day.start, to: day.end)
    }

    /// What today held back, grouped ("See what I held").
    public func heldToday(now: Date = Date()) throws -> [HeldGroup] {
        let day = calendar.dateInterval(of: .day, for: now)!
        return try store.heldBack(from: day.start, to: day.end)
    }

    /// Monday to Friday of this week, one summary per day (the weekly card's chart).
    public func weekDays(now: Date = Date()) throws -> [DaySummary] {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        var days: [DaySummary] = []
        var d = week.start
        while days.count < 7, d < week.end {
            let next = calendar.date(byAdding: .day, value: 1, to: d)!
            let wd = calendar.component(.weekday, from: d)
            if wd != 1 && wd != 7 { days.append(try store.daySummary(from: d, to: next)) }
            d = next
        }
        return days
    }

    /// This calendar week so far (the held-back ledger in the menu and Friday's tuck-in).
    public func weekSummary(now: Date = Date()) throws -> DaySummary {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        return try store.daySummary(from: week.start, to: week.end)
    }

    // Agent task log (the store has one owner: this actor).
    public func save(_ task: AgentTask) throws { try store.save(task) }
    public func agentTasks(limit: Int = 50) throws -> [AgentTask] { try store.agentTasks(limit: limit) }
    public func deleteAgentTasks() throws { try store.deleteAgentTasks() }

    /// "What Hush saw" (ADR-026): the last `days` days, after dropping anything older than the journal keeps.
    public func journal(days: Int = Journal.keepDays, now: Date = Date()) throws -> [LoggedDecision] {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: now)!
        try store.prune(before: calendar.date(byAdding: .day, value: -Journal.keepDays, to: now)!)
        return try store.journal(since: cutoff)
    }

    public func pruneJournal(now: Date = Date()) throws {
        try store.prune(before: calendar.date(byAdding: .day, value: -Journal.keepDays, to: now)!)
    }

    public func forgetJournal() throws { try store.deleteDecisions() }

    public func recentDecisions(limit: Int = 50) throws -> [LoggedDecision] {
        try store.recentDecisions(limit: limit)
    }
}
