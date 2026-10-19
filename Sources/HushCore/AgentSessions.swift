import Foundation

/// Coding agents Hush watches through their hooks. Same thin status events from each.
public enum AgentKind: String, Sendable, CaseIterable {
    case claude, codex

    /// "Claude finished in hush", "Codex needs you in hush".
    public var shortName: String { self == .claude ? "Claude" : "Codex" }
    public var senderName: String { self == .claude ? "Claude Code" : "Codex" }
}

/// One status event from a coding-agent session (Claude Code or Codex), as forwarded by `hushctl` from a hook.
/// Deliberately thin: hooks also carry your prompt, Claude's reply and tool inputs, and none of that ever crosses over.
public struct AgentSessionEvent: Sendable, Equatable {
    public enum Kind: String, Sendable, CaseIterable {
        case start      // SessionStart
        case prompt     // UserPromptSubmit: you asked for something; it's working
        case tool       // PostToolUse: still working (and any approval it was waiting on was answered)
        case needsYou   // Notification about a permission prompt
        case stop       // Stop: the turn finished
        case end        // SessionEnd
    }

    public var sessionID: String
    public var cwd: String
    public var kind: Kind
    /// Bundle id of the app hosting the session (Terminal, iTerm, Cursor…), if hushctl could tell.
    public var app: String?
    public var at: Date
    public var agent: AgentKind
    /// The terminal device ("/dev/ttys003"), so a message can reach the right tab.
    public var tty: String?

    public init(sessionID: String, cwd: String, kind: Kind, app: String? = nil, at: Date, agent: AgentKind = .claude, tty: String? = nil) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.kind = kind
        self.app = app
        self.at = at
        self.agent = agent
        self.tty = tty
    }

    /// The repo / folder name shown on the card.
    public var project: String { URL(fileURLWithPath: cwd).lastPathComponent }
}

/// Tracks your Claude Code sessions and decides what's worth Hush's attention (Phase 1, docs/agent-plan.md).
/// Many sessions run at once, so everything is keyed by session id, and nothing surfaces for runs you're watching.
public struct AgentSessionTracker: Sendable {
    public struct Session: Sendable, Equatable {
        public var cwd: String
        public var app: String?
        public var workingSince: Date?
        public var lastEvent: Date
        public var waitingForYou = false
        public var approvalsAsked = 0
        public var runs = 0
        /// Claude Code or Codex.
        public var agent: AgentKind = .claude
        public var tty: String?
    }

    /// A run must last this long before its "done" earns an envelope (quick runs you're watching don't).
    public var minRunForEnvelope: TimeInterval = 2 * 60
    /// Working this long while you're elsewhere → Hush shows it's thinking.
    public var thinkingAfter: TimeInterval = 20
    /// No events for this long while "working" → assume it died (killed terminal, crash).
    public var staleAfter: TimeInterval = 15 * 60

    public private(set) var sessions: [String: Session] = [:]
    /// Sessions you asked Hush to watch ("let me know when it finishes"). One-shot: cleared when it fires.
    public private(set) var watched: Set<String> = []

    public init() {}

    public mutating func watch(_ sessionID: String) { watched.insert(sessionID) }
    public mutating func unwatch(_ sessionID: String) { watched.remove(sessionID) }

    /// Feed one event. `frontmostApp` is the bundle id of the app in front right now.
    /// Returns items to hand to the DecisionEngine (always gentle; the engine applies caps, focus and quiet hours).
    public mutating func handle(_ e: AgentSessionEvent, frontmostApp: String?) -> [InboxItem] {
        var s = sessions[e.sessionID] ?? Session(cwd: e.cwd, app: e.app, lastEvent: e.at)
        s.lastEvent = e.at
        if let app = e.app { s.app = app }
        s.agent = e.agent
        if let tty = e.tty { s.tty = tty }
        let watching = s.app != nil && s.app == frontmostApp
        var out: [InboxItem] = []

        switch e.kind {
        case .start:
            break
        case .prompt:
            s.workingSince = s.workingSince ?? e.at
            s.waitingForYou = false
        case .tool:
            s.workingSince = s.workingSince ?? e.at
            s.waitingForYou = false
        case .needsYou:
            guard !s.waitingForYou else { break }
            s.waitingForYou = true
            s.approvalsAsked += 1
            if !watching {
                out.append(item(e, s, id: "agent:\(e.sessionID):approval:\(s.approvalsAsked)",
                                subject: "\(e.agent.shortName) needs you in \(e.project)", snippet: "Waiting for a permission prompt"))
            }
        case .stop where watched.contains(e.sessionID):
            // You asked to be told: always, even for a short run or one you're looking at.
            watched.remove(e.sessionID)
            s.runs += 1
            let ran = s.workingSince.map { e.at.timeIntervalSince($0) }
            out.append(item(e, s, id: "agent:\(e.sessionID):watched:\(s.runs)",
                            subject: "\(e.agent.shortName) finished in \(e.project)",
                            snippet: ran.map { "Ran for \(Self.duration($0)) · you asked me to watch it" } ?? "You asked me to watch it"))
            s.workingSince = nil
            s.waitingForYou = false
        case .stop:
            if let since = s.workingSince {
                let ran = e.at.timeIntervalSince(since)
                s.runs += 1
                if ran >= minRunForEnvelope && !watching {
                    out.append(item(e, s, id: "agent:\(e.sessionID):done:\(s.runs)",
                                    subject: "\(e.agent.shortName) finished in \(e.project)", snippet: "Ran for \(Self.duration(ran))"))
                }
            }
            s.workingSince = nil
            s.waitingForYou = false
        case .end:
            sessions[e.sessionID] = nil
            watched.remove(e.sessionID)
            return out
        }
        sessions[e.sessionID] = s
        return out
    }

    /// Folder of the session that was active most recently (the default repo for "Ask Hush").
    public var mostRecentCwd: String? { sessions.values.max(by: { $0.lastEvent < $1.lastEvent })?.cwd }

    /// Is a session working somewhere you're not looking? (ambient "thinking" pose)
    public func workingInBackground(now: Date, frontmostApp: String?) -> Bool {
        sessions.values.contains { s in
            guard let since = s.workingSince, !s.waitingForYou else { return false }
            return now.timeIntervalSince(since) >= thinkingAfter
                && now.timeIntervalSince(s.lastEvent) < staleAfter
                && !(s.app != nil && s.app == frontmostApp)
        }
    }

    /// Drop sessions that went quiet mid-run (terminal closed without SessionEnd).
    public mutating func prune(now: Date) {
        sessions = sessions.filter { now.timeIntervalSince($0.value.lastEvent) < max(staleAfter, 6 * 3600) }
        for (id, s) in sessions where s.workingSince != nil && now.timeIntervalSince(s.lastEvent) >= staleAfter {
            sessions[id]?.workingSince = nil
        }
    }

    private func item(_ e: AgentSessionEvent, _ s: Session, id: String, subject: String, snippet: String) -> InboxItem {
        InboxItem(id: id, kind: .agent, senderName: e.agent.senderName, senderAddress: nil, subject: subject,
                  snippet: snippet, receivedAt: e.at, sourceApp: s.app, project: e.project)
    }

    static func duration(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        return m < 60 ? "\(max(1, m)) min" : "\(m / 60) h \(m % 60) min"
    }
}
