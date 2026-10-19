import Foundation

/// The Ask Hush eval set (`evals/asks.json`, docs/lanes-plan.md § L2): routing is checked free in tests,
/// answers by `hush-eval` against a real model.
public struct AskEvalSet: Sendable, Decodable {
    public struct Case: Sendable, Decodable {
        public var ask: String
        /// Bundle id of the app the ask comes from.
        public var app: String?
        /// "quick", "repo", "handoff" or "do" (a browser task).
        public var lane: String
        public var shape: AnswerShape.Kind?
        public var contains: [String]?
    }

    /// A stand-in allowed repo, so code questions have somewhere to go.
    public var repo: String
    public var cases: [Case]

    public static func load(_ url: URL) throws -> AskEvalSet {
        try JSONDecoder().decode(AskEvalSet.self, from: Data(contentsOf: url))
    }

    public func context(for c: Case) -> AskContext {
        AskContext(frontmostApp: c.app, repos: [repo], defaultRepo: repo, browserTasks: true)
    }

    /// The lane name for a route (hand-offs collapse to "handoff").
    public static func laneName(_ lane: AskLane) -> String {
        switch lane {
        case .quick: "quick"
        case .repo: "repo"
        case .handoff: "handoff"
        case .browser: "do"
        case .sessions: "sessions"
        }
    }

    /// Problems with a quick answer, empty when it passes.
    public static func grade(_ answer: AnswerShape?, against c: Case) -> [String] {
        guard let a = answer else { return ["no structured answer"] }
        var problems: [String] = []
        if let want = c.shape, a.shape != want { problems.append("shape \(a.shape.rawValue), wanted \(want.rawValue)") }
        let text = a.plainText.lowercased()
        for s in c.contains ?? [] where !text.contains(s.lowercased()) { problems.append("missing \"\(s)\"") }
        return problems
    }
}
