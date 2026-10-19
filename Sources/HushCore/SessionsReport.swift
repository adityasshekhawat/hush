import Foundation

/// Ask Hush about your coding-agent sessions ("what's Claude doing?"), answered on the Mac with no model call:
/// live state from the hooks (working, waiting for you) merged with the opt-in transcripts (what you asked, what
/// Claude said, files, commits). Pure, so it's testable.
public struct SessionLine: Sendable, Equatable, Identifiable {
    public enum Status: Sendable, Equatable {
        case waiting            // a permission prompt is open
        case working(since: Date)
        case finished
        case stopped
        case idle
    }

    public var id: String
    public var agent: AgentKind
    public var project: String
    public var branch: String?
    public var status: Status
    /// Bundle id of the app it runs in (Terminal, Cursor…), for Open.
    public var app: String?
    /// Its terminal device, for sending it a message.
    public var tty: String?
    public var title: String?
    public var lastPrompt: String?
    public var lastMessage: String?
    public var files: [String]
    public var commits: Int
    public var pullRequests: [String]
    public var lastActivity: Date
    /// The transcript digest, when the digest is on (Summarise needs it).
    public var digest: SessionDigest?
}

public enum SessionsReport {
    /// Live sessions quiet for longer than this aren't worth listing.
    public static let liveWindow: TimeInterval = 6 * 3600
    /// How far back transcripts are read.
    public static let transcriptWindow: TimeInterval = 3 * 3600
    public static let maxLines = 5

    public static func lines(live: [String: AgentSessionTracker.Session], digests: [SessionDigest], now: Date) -> [SessionLine] {
        var out: [String: SessionLine] = [:]
        for d in digests {
            out[d.sessionID] = SessionLine(
                id: d.sessionID, agent: .claude, project: d.project, branch: d.branch,
                status: d.status == .working ? .working(since: d.start) : d.status == .finished ? .finished : .stopped,
                app: nil, tty: nil, title: d.title, lastPrompt: d.lastPrompt, lastMessage: d.lastMessage,
                files: d.filesChanged, commits: d.commits, pullRequests: d.pullRequests, lastActivity: d.end, digest: d)
        }
        for (id, s) in live where now.timeIntervalSince(s.lastEvent) < liveWindow {
            var line = out[id] ?? SessionLine(
                id: id, agent: s.agent, project: URL(fileURLWithPath: s.cwd).lastPathComponent, branch: nil, status: .idle,
                app: nil, tty: nil, title: nil, lastPrompt: nil, lastMessage: nil, files: [], commits: 0, pullRequests: [],
                lastActivity: s.lastEvent, digest: nil)
            line.agent = s.agent
            line.app = s.app
            line.tty = s.tty
            line.lastActivity = max(line.lastActivity, s.lastEvent)
            // Live state is fresher than the transcript.
            if s.waitingForYou { line.status = .waiting }
            else if let since = s.workingSince { line.status = .working(since: since) }
            else if case .working = line.status { line.status = .finished }
            out[id] = line
        }
        return out.values.sorted { a, b in
            if rank(a.status) != rank(b.status) { return rank(a.status) < rank(b.status) }
            return a.lastActivity > b.lastActivity
        }
    }

    static func rank(_ s: SessionLine.Status) -> Int {
        switch s {
        case .waiting: 0
        case .working: 1
        case .finished: 2
        case .stopped: 3
        case .idle: 4
        }
    }

    /// "2 sessions: 1 needs you, 1 working."
    public static func headline(_ lines: [SessionLine]) -> String {
        guard !lines.isEmpty else { return "No sessions in the last few hours." }
        let waiting = lines.filter { $0.status == .waiting }.count
        let working = lines.filter { if case .working = $0.status { return true } else { return false } }.count
        let finished = lines.filter { $0.status == .finished }.count
        var parts: [String] = []
        if waiting > 0 { parts.append("\(waiting) \(waiting == 1 ? "needs" : "need") you") }
        if working > 0 { parts.append("\(working) working") }
        if finished > 0 { parts.append("\(finished) finished") }
        let n = lines.count == 1 ? "1 session" : "\(lines.count) sessions"
        return parts.isEmpty ? "\(n), all quiet." : "\(n): \(parts.joined(separator: ", "))."
    }

    /// "working for 6 min", "needs you", "finished 12 min ago".
    public static func statusText(_ line: SessionLine, now: Date) -> String {
        switch line.status {
        case .waiting: return "needs you"
        case .working(let since): return "working for \(duration(now.timeIntervalSince(since)))"
        case .finished: return "finished \(duration(now.timeIntervalSince(line.lastActivity))) ago"
        case .stopped: return "stopped \(duration(now.timeIntervalSince(line.lastActivity))) ago"
        case .idle: return "idle"
        }
    }

    static func duration(_ t: TimeInterval) -> String {
        let m = max(0, Int(t / 60))
        return m < 1 ? "under a minute" : m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
    }

    /// Plain text of the report: Copy, history, and the context a follow-up question sends.
    public static func plainText(_ lines: [SessionLine], now: Date) -> String {
        var s = headline(lines)
        for l in lines.prefix(maxLines) {
            s += "\n\n\(l.project)\(l.branch.map { " (\($0))" } ?? ""), \(l.agent.shortName): \(statusText(l, now: now))."
            if let t = l.title { s += "\nSession: \(t)" }
            if let p = l.lastPrompt { s += "\nYou asked: \(p.prefix(300))" }
            if let m = l.lastMessage { s += "\n\(l.agent.shortName) said: \(m.prefix(500))" }
            if !l.files.isEmpty { s += "\nFiles changed: \(l.files.prefix(8).joined(separator: ", "))" }
            if l.commits > 0 { s += "\nCommits: \(l.commits)" }
        }
        return s
    }
}

/// Is a question about your running agent sessions, rather than about Claude in general? It needs both an agent
/// ("Claude", "Codex", "agent") and a word about sessions or their state ("sessions", "running", "doing", "stuck").
/// "What all claude sessions are running?" yes; "is Claude better than ChatGPT?" no; "Claude Code tutorial" no.
public enum SessionQuestion {
    static let agents = ["claude", "codex", "agent", "agents", "cc"]
    static let states = ["session", "sessions", "running", "run", "runs", "doing", "working", "work", "busy", "done",
                         "finished", "finish", "stuck", "waiting", "happening", "status", "progress", "active", "open",
                         "up", "left", "going", "still", "now", "currently", "idle"]
    /// Phrases that are enough on their own.
    static let phrases = ["my session", "my sessions", "my agent", "my agents", "is it done yet", "sessions running",
                          "what's running", "whats running", "what is running"]

    public static func matches(_ text: String) -> Bool {
        let t = text.lowercased().replacingOccurrences(of: "’", with: "'")
        if phrases.contains(where: t.contains) { return true }
        let words = Set(t.split(whereSeparator: { !$0.isLetter }).map(String.init))
        return !words.isDisjoint(with: agents) && !words.isDisjoint(with: states)
    }
}

/// Commands to Hush itself, as opposed to questions about sessions or messages to Claude:
/// "keep watching this session and let me know when it finishes", "stop watching site".
public enum HushCommand: Sendable, Equatable {
    case watch
    case unwatch

    static let watchPhrases = ["let me know when", "tell me when", "notify me when", "ping me when", "keep watching",
                               "keep an eye on", "watch this", "watch the", "watch it", "watch my", "alert me when"]
    static let unwatchPhrases = ["stop watching", "don't watch", "dont watch", "cancel the watch", "no need to watch"]

    public static func parse(_ text: String) -> HushCommand? {
        let t = text.lowercased().replacingOccurrences(of: "’", with: "'")
        if unwatchPhrases.contains(where: t.contains) { return .unwatch }
        if watchPhrases.contains(where: t.contains) { return .watch }
        return nil
    }

    public enum Target: Sendable, Equatable {
        case one(String)
        case ambiguous([String])
        case none
    }

    /// Which session a command or question means: the one you opened, else one named by project, else the only
    /// working (or only) session. Several candidates: ambiguous, so the card asks.
    public static func target(_ text: String, sessions: [SessionLine], selected: String?) -> Target {
        if let s = selected { return .one(s) }
        let t = " " + text.lowercased() + " "
        let named = sessions.filter { t.contains(" " + $0.project.lowercased()) || t.contains($0.project.lowercased() + " ") }
        if named.count == 1 { return .one(named[0].id) }
        if named.count > 1 { return .ambiguous(named.map(\.id)) }
        let working = sessions.filter { if case .working = $0.status { return true } else { return $0.status == .waiting } }
        if working.count == 1 { return .one(working[0].id) }
        if sessions.count == 1 { return .one(sessions[0].id) }
        if sessions.isEmpty { return .none }
        return .ambiguous((working.isEmpty ? sessions : working).map(\.id))
    }
}
