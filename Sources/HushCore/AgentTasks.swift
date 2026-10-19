import Foundation

/// One question or task you gave Hush's agent. Logged locally (Principle 4: scrutable): prompt, tools used, result, cost.
public struct AgentTask: Sendable, Equatable {
    public enum Status: String, Sendable, Codable { case running, done, failed, cancelled }

    public var id: String
    public var startedAt: Date
    public var repo: String
    public var prompt: String
    public var status: Status
    public var result: String
    public var toolsUsed: [String]
    public var costUSD: Double
    public var durationMS: Int
    public var contextTokens: Int
    public var model: String

    public init(id: String = UUID().uuidString, startedAt: Date, repo: String, prompt: String, model: String) {
        self.id = id
        self.startedAt = startedAt
        self.repo = repo
        self.prompt = prompt
        self.status = .running
        self.result = ""
        self.toolsUsed = []
        self.costUSD = 0
        self.durationMS = 0
        self.contextTokens = 0
        self.model = model
    }

    public var repoName: String { URL(fileURLWithPath: repo).lastPathComponent }
}

/// Phase 2 profile: read-only. Claude Code tool names / patterns passed as the run's allowlist (docs/agent-plan.md).
public enum ReadOnlyProfile {
    public static let allowedTools = [
        "Read", "Grep", "Glob",
        "Bash(git log:*)", "Bash(git diff:*)", "Bash(git status:*)", "Bash(git show:*)", "Bash(git blame:*)",
        "Bash(git branch:*)", "Bash(git rev-parse:*)",
        "Bash(gh pr view:*)", "Bash(gh pr list:*)", "Bash(gh pr checks:*)", "Bash(gh pr diff:*)",
        "Bash(gh run list:*)", "Bash(gh run view:*)",
    ]

    /// Added to the lean system prompt: what this mode can and can't do.
    public static let instructions = """
        This is read-only mode: you can read files, search, and run read-only git and gh commands. You cannot edit \
        files or run anything else; if the task needs that, say what you would do instead. You are already in the \
        repository: run git as plain `git log …`, `git diff …` (never `git -C`, `cd … &&`, pipes or chained commands), \
        or those calls are refused.
        """
}

/// Which repository a question is about (pure, so it's testable).
public enum RepoChooser {
    /// Priority: the repo you picked in the box → the folder of your most recent Claude Code session (if allowed)
    /// → the last repo you asked about → the first allowed repo. Only allowed repos are ever returned.
    public static func choose(picked: String?, recentSessionCwd: String?, lastUsed: String?, allowed: [String]) -> String? {
        let allowedSet = Set(allowed.map(normalize))
        func ok(_ p: String?) -> String? {
            guard let p else { return nil }
            let n = normalize(p)
            // A session in a subfolder of an allowed repo counts as that repo.
            if allowedSet.contains(n) { return n }
            return allowedSet.filter { n.hasPrefix($0 + "/") }.max(by: { $0.count < $1.count })
        }
        return ok(picked) ?? ok(recentSessionCwd) ?? ok(lastUsed) ?? allowed.first.map(normalize)
    }

    static func normalize(_ p: String) -> String {
        var s = (p as NSString).standardizingPath
        while s.count > 1 && s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
