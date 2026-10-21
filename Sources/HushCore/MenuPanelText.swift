import Foundation

/// What the menu bar panel says (design guide 09b, panel v2): one plain sentence answering "does anything need me?",
/// in Hush's voice, then a line for each place. Pure, so every state is tested.
public enum MenuPanelText {
    public enum Dot: Sendable, Equatable { case none, needsYou, paused }

    public struct Header: Sendable, Equatable {
        public var title: String
        public var subtitle: String
        public var dot: Dot
        /// The avatar's expression (an expression file in the pack) for this state.
        public var expression: String
    }

    public enum Situation: Sendable, Equatable {
        /// Short labels of what waits, newest first ("Claude in hush", "a meeting soon").
        case waiting([String])
        case paused(until: Date)
        case setup(stepsLeft: Int)
        case focused
        case asleep
        case quiet
    }

    /// Waiting beats paused (you opened the panel; show what's there), paused beats setup, setup beats the rest.
    public static func situation(waiting: [String], pausedUntil: Date?, setupLeft: Int, focused: Bool, asleep: Bool) -> Situation {
        if !waiting.isEmpty { return .waiting(waiting) }
        if let until = pausedUntil { return .paused(until: until) }
        if setupLeft > 0 { return .setup(stepsLeft: setupLeft) }
        if focused { return .focused }
        if asleep { return .asleep }
        return .quiet
    }

    public static func header(_ s: Situation, now: Date, calendar: Calendar = .current) -> Header {
        switch s {
        case .waiting(let labels):
            let n = labels.count
            return Header(title: n == 1 ? "1 thing needs you" : "\(n) things need you",
                          subtitle: labels.prefix(2).joined(separator: " · ") + (n > 2 ? " · \(n - 2) more" : ""),
                          dot: .needsYou, expression: "surprised")
        case .paused(let until):
            return Header(title: PauseText.status(until: until, now: now, calendar: calendar),
                          subtitle: "I'll keep what comes in for later", dot: .paused, expression: "sleepy")
        case .setup(let left):
            return Header(title: "Almost set up", subtitle: left == 1 ? "One step left" : "\(left) steps left",
                          dot: .none, expression: "happy")
        case .focused:
            return Header(title: "Staying out of your way", subtitle: "You're busy, so things wait for now",
                          dot: .none, expression: "neutral")
        case .asleep:
            return Header(title: "Asleep", subtitle: "Things wait until morning", dot: .none, expression: "sleepy")
        case .quiet:
            return Header(title: "All quiet", subtitle: "Nothing needs you right now", dot: .none, expression: "neutral")
        }
    }

    /// The "held back today" tile's second line; nil means the empty state.
    public static func today(held: Int, shown: Int) -> (number: String, line: String)? {
        guard held > 0 || shown > 0 else { return nil }
        return ("\(held)", "\(shown) shown to you · Open journal")
    }
    public static let todayEmpty = ("Nothing held back yet today", "I'll keep count as things come in.")

    public enum AgentsState: Sendable, Equatable { case notConnected, needsUpdate, needsYou, running, idle }

    /// The Agents row: its line, and which dot (if any) goes beside the chevron.
    public static func agents(watching: Bool, needsUpdate: Bool, running: Int, needsYou: Int) -> (line: String, state: AgentsState) {
        guard watching else { return ("Not watching yet · Connect", .notConnected) }
        if needsUpdate { return ("Update my hooks", .needsUpdate) }
        if needsYou > 0 {
            let line = (needsYou == 1 ? "1 needs you" : "\(needsYou) need you") + (running > 0 ? " · \(running) running" : "")
            return (line, .needsYou)
        }
        if running > 0 { return (running == 1 ? "1 session running" : "\(running) sessions running", .running) }
        return ("Watching · nothing running", .idle)
    }

    /// "3 sessions ran · 40 min" for the While you were away row.
    public static func away(sessions: Int, minutes: Int) -> String {
        (sessions == 1 ? "1 session ran" : "\(sessions) sessions ran") + " · " + (minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
    }

    public static func ask(questionsThisMonth n: Int) -> String {
        n == 0 ? "Ask anything, from any app" : n == 1 ? "1 question this month" : "\(n) questions this month"
    }

    /// The panel shows up to 3 waiting rows; past that, 2 rows and "and N more".
    public static func waitingRows(_ count: Int) -> (rows: Int, more: Int) {
        count <= 3 ? (count, 0) : (2, count - 2)
    }
}

extension AgentSessionTracker {
    /// Sessions working right now (not stale, not waiting) and sessions waiting for you, for the panel's Agents row.
    public func counts(now: Date) -> (running: Int, needsYou: Int) {
        let live = sessions.values.filter { now.timeIntervalSince($0.lastEvent) < staleAfter }
        return (live.filter { $0.workingSince != nil && !$0.waitingForYou }.count, live.filter(\.waitingForYou).count)
    }
}
