import Foundation

/// The smarter router's other two layers (the first is AskRouter's rules):
/// - learned routes: when you change the lane before sending, that phrasing goes your way next time;
/// - a model check: when the rules aren't sure, a quick model picks the lane from what Hush knows.
/// Pure, so it's testable; storage and the model call live in the app.

/// A lane without its details, for storage and the model's answer.
public enum LaneKind: String, Sendable, Codable, CaseIterable {
    case quick, repo, handoff, sessions, browser

    public init(_ lane: AskLane) {
        switch lane {
        case .quick: self = .quick
        case .repo: self = .repo
        case .handoff: self = .handoff
        case .sessions: self = .sessions
        case .browser: self = .browser
        }
    }

    /// Back to a full lane in this context (nil when it can't apply, e.g. repo with no allowed repo).
    public func lane(for question: String, context c: AskContext) -> AskLane? {
        switch self {
        case .quick: return .quick
        case .sessions: return .sessions
        case .handoff: return .handoff(c.preferredHandoff)
        case .browser: return c.browserTasks ? .browser : nil
        case .repo:
            let q = question.lowercased()
            if let named = c.repos.first(where: { q.contains(URL(fileURLWithPath: $0).lastPathComponent.lowercased()) }) { return .repo(path: named) }
            return c.defaultRepo.map { .repo(path: $0) }
        }
    }
}

public struct LearnedRoutes: Sendable, Equatable, Codable {
    public struct Entry: Sendable, Equatable, Codable {
        public var words: [String]
        public var lane: LaneKind
        public var at: Date
    }

    public static let limit = 200
    public private(set) var entries: [Entry] = []
    public init() {}

    static let stop: Set<String> = ["the", "a", "an", "is", "are", "my", "me", "i", "to", "in", "of", "and", "what", "whats",
                                    "how", "do", "does", "can", "you", "please", "for", "on", "it", "this", "that", "all"]

    /// Meaningful words, lowercased, in order.
    public static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            .filter { $0.count > 1 && !stop.contains($0) }
    }

    /// You sent `text` on `lane` after changing it from what the rules picked.
    public mutating func record(_ text: String, lane: LaneKind, at: Date = Date()) {
        let w = Self.words(text)
        guard !w.isEmpty else { return }
        entries.removeAll { $0.words == w }
        entries.append(Entry(words: w, lane: lane, at: at))
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
    }

    /// The lane a close-enough earlier correction points to: most of this question's words, and most of that one's.
    public func lookup(_ text: String) -> LaneKind? {
        let w = Set(Self.words(text))
        guard w.count >= 2 else { return nil }
        var best: (score: Double, lane: LaneKind)?
        for e in entries.reversed() {
            let other = Set(e.words)
            let shared = Double(w.intersection(other).count)
            let score = min(shared / Double(w.count), shared / Double(other.count))
            if score >= 0.75, score > (best?.score ?? 0) { best = (score, e.lane) }
        }
        return best?.lane
    }
}

/// The model check: prompt, schema and parsing.
public enum RouteCheck {
    public static func systemPrompt(context c: AskContext, runningSessions: Int) -> String {
        var lanes = [
            "quick: a short answer right away (facts, how-tos, formulas, shell commands, definitions).",
            "handoff: long writing, brainstorming, research, advice or a conversation; it opens the user's chat assistant.",
            "sessions: about the user's own Claude Code or Codex sessions on this Mac (what is running, status, progress, what an agent did), or asking Hush to watch one and say when it finishes. \(runningSessions) session(s) active now.",
        ]
        if !c.repos.isEmpty {
            let names = c.repos.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            lanes.insert("repo: a question about the code in one of the user's repositories (\(names)): where something is, how it works, recent commits.", at: 1)
        }
        if c.browserTasks { lanes.append("browser: do a task in a web browser (fill a form, make a sheet, search a site).") }
        return """
            You route a question typed into Hush, a companion app on the user's Mac. Pick exactly one lane:
            \(lanes.map { "- " + $0 }.joined(separator: "\n"))
            \(c.appName.map { "The user is in \($0)." } ?? "")
            Answer with the lane and a reason of at most 6 words. Do not answer the question itself.
            """
    }

    public static func jsonSchema(context c: AskContext) -> String {
        var names = ["quick", "handoff", "sessions"]
        if !c.repos.isEmpty { names.insert("repo", at: 1) }
        if c.browserTasks { names.append("browser") }
        let list = names.map { "\"\($0)\"" }.joined(separator: ",")
        return #"{"type":"object","additionalProperties":false,"required":["lane","why"],"properties":{"lane":{"type":"string","enum":["# + list + #"]},"why":{"type":"string"}}}"#
    }

    /// The model's JSON → a lane in this context.
    public static func parse(_ data: Data, question: String, context c: AskContext) -> (lane: AskLane, why: String)? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = o["lane"] as? String, let kind = LaneKind(rawValue: raw),
              let lane = kind.lane(for: question, context: c) else { return nil }
        return (lane, (o["why"] as? String).map { String($0.prefix(60)) } ?? "")
    }
}
