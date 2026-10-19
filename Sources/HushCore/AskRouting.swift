import Foundation

/// Where a typed question goes (docs/ask-design.md). Decided in code, shown before you press Enter.
public enum AskLane: Sendable, Equatable {
    /// One fast model call, structured answer, no tools.
    case quick
    /// Read-only run in a repository.
    case repo(path: String)
    /// Open an assistant app with the question pre-filled.
    case handoff(Provider)
    /// A task done in your Chrome after you approve its plan (docs/lanes-plan.md § L3; off until enabled).
    case browser
    /// Your Claude Code / Codex sessions, answered on the Mac from hooks and transcripts (no model call).
    case sessions

    public enum Provider: String, Sendable, CaseIterable {
        case chatgpt, claude, perplexity

        public var displayName: String {
            switch self {
            case .chatgpt: "ChatGPT"
            case .claude: "Claude"
            case .perplexity: "Perplexity"
            }
        }

        /// Pre-filled new-conversation URL. `appInstalled`: Claude's desktop app registers claude://.
        public func url(for text: String, appInstalled: Bool) -> URL? {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&+=?#")
            let q = text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            switch self {
            case .chatgpt: return URL(string: "https://chatgpt.com/?q=\(q)")
            case .claude: return URL(string: appInstalled ? "claude://claude.ai/new?q=\(q)" : "https://claude.ai/new?q=\(q)")
            case .perplexity: return URL(string: "https://www.perplexity.ai/search?q=\(q)")
            }
        }
    }
}

public struct AskRoute: Sendable, Equatable {
    public var lane: AskLane
    /// The question with any @prefix removed.
    public var text: String
    /// Short reason for the chip's tooltip ("names hush", "long, open-ended").
    public var why: String
    /// True when you chose it (prefix or Tab), so Hush never second-guesses it.
    public var explicit: Bool
    /// False when only the fallback matched ("short question"): the smarter router may ask a model on submit.
    public var confident: Bool = true

    public init(lane: AskLane, text: String, why: String, explicit: Bool, confident: Bool = true) {
        self.lane = lane
        self.text = text
        self.why = why
        self.explicit = explicit
        self.confident = confident
    }
}

public struct AskContext: Sendable {
    /// Bundle id of the app you were in when you opened the box.
    public var frontmostApp: String?
    /// Allowed repos (absolute paths) and the one Hush would pick by default.
    public var repos: [String]
    public var defaultRepo: String?
    public var preferredHandoff: AskLane.Provider
    /// The browser-task lane is switched on (Agent ▸ Browser tasks).
    public var browserTasks: Bool

    public init(frontmostApp: String? = nil, repos: [String] = [], defaultRepo: String? = nil,
                preferredHandoff: AskLane.Provider = .chatgpt, browserTasks: Bool = false) {
        self.frontmostApp = frontmostApp
        self.repos = repos
        self.defaultRepo = defaultRepo
        self.preferredHandoff = preferredHandoff
        self.browserTasks = browserTasks
    }

    static let codeApps: Set<String> = [
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "dev.warp.Warp-Stable", "com.apple.Terminal", "com.googlecode.iterm2", "com.microsoft.VSCode",
        "com.mitchellh.ghostty", "dev.zed.Zed",
    ]
    public var inCodeApp: Bool { frontmostApp.map(Self.codeApps.contains) ?? false }

    /// A human name for the app, for "in Excel" hints and the quick-lane prompt.
    public var appName: String? {
        switch frontmostApp {
        case "com.microsoft.Excel": "Microsoft Excel"
        case "com.apple.iWork.Numbers": "Numbers"
        case "notion.id": "Notion"
        case "md.obsidian": "Obsidian"
        case "com.figma.Desktop": "Figma"
        case "com.todesktop.230313mzl4w4u92": "Cursor"
        case "dev.warp.Warp-Stable": "Warp"
        case "com.apple.Terminal": "Terminal"
        case "com.microsoft.VSCode": "VS Code"
        case "com.tinyspeck.slackmacgap": "Slack"
        case "ai.perplexity.comet", "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser": "a web browser"
        default: nil
        }
    }
}

public enum AskRouter {
    static let prefixes: [(String, @Sendable (AskContext) -> AskLane?)] = [
        ("@chatgpt", { _ in .handoff(.chatgpt) }), ("@gpt", { _ in .handoff(.chatgpt) }),
        ("@claude", { _ in .handoff(.claude) }),
        ("@perplexity", { _ in .handoff(.perplexity) }), ("@pplx", { _ in .handoff(.perplexity) }),
        ("@quick", { _ in .quick }),
        ("@code", { c in c.defaultRepo.map { .repo(path: $0) } }),
        ("@do", { c in c.browserTasks ? .browser : nil }),
        ("@sessions", { _ in .sessions }),
    ]

    /// Clearly about *your* code: enough on their own.
    static let strongCode = ["this repo", "the repo", "our repo", "my repo", "in the code", "codebase", "our code", "my code",
                             "which file", "where is", "where's", "defined", "stack trace", "build error", "test fail",
                             "pr #", "this pr", "my pr", "our pr", "last commit", "latest commit", "recent commits",
                             "my branch", "this branch", "the branch", ".swift", ".ts", ".tsx", ".py", ".js", ".go", ".rs",
                             "/src", "sources/", "readme"]
    /// Code-ish words that need a pointer to *this* project ("my", "our", "this", "the", "in hush") to count.
    /// Without one, "how do I undo a git commit" is a general how-to: a quick answer.
    static let weakCode = ["function", "commit", "pull request", "diff", "branch", "refactor", "class", "module", "test", "bug"]
    static let deictic = ["my ", "our ", "this ", "these ", "in here", "last ", "latest ", "recent ", "today", "yesterday"]
    static let openEnded = ["plan ", "brainstorm", "write me", "write a ", "draft a ", "help me think", "in depth",
                            "research", "essay", "pros and cons", "strategy", "ideas for", "itinerary", "story"]

    public static func route(_ raw: String, context c: AskContext) -> AskRoute {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // 1. Explicit prefix: @gpt, @claude, @perplexity, @quick, @code, @<repo name>.
        if lower.hasPrefix("@") {
            let word = String(lower.prefix { !$0.isWhitespace })
            let rest = String(trimmed.dropFirst(word.count)).trimmingCharacters(in: .whitespaces)
            if let (_, make) = prefixes.first(where: { $0.0 == word }), let lane = make(c) {
                return AskRoute(lane: lane, text: rest, why: "you chose \(word)", explicit: true)
            }
            if let repo = c.repos.first(where: { "@" + URL(fileURLWithPath: $0).lastPathComponent.lowercased() == word }) {
                return AskRoute(lane: .repo(path: repo), text: rest, why: "you chose \(word)", explicit: true)
            }
        }

        // 2. About your running agent sessions ("what's Claude doing?").
        if SessionQuestion.matches(trimmed) || HushCommand.parse(trimmed) != nil {
            return AskRoute(lane: .sessions, text: trimmed, why: "about your sessions", explicit: false)
        }

        // 2b. A task for the browser ("make a google sheet of…"), when that lane is on.
        if c.browserTasks, DoIntent.matches(trimmed) {
            return AskRoute(lane: .browser, text: trimmed, why: "a task for your browser", explicit: false)
        }

        // 3. Names an allowed repo, or talks about code while a repo is available.
        if let repo = c.repos.first(where: { lower.contains(URL(fileURLWithPath: $0).lastPathComponent.lowercased()) }) {
            return AskRoute(lane: .repo(path: repo), text: trimmed,
                            why: "mentions \(URL(fileURLWithPath: repo).lastPathComponent)", explicit: false)
        }
        let padded = " \(lower) "
        let words = Set(lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "#" && $0 != "/" }).map(String.init))
        let strong = strongCode.contains { padded.contains($0) }
        let weak = weakCode.contains { words.contains($0) || words.contains($0 + "s") || words.contains($0 + "es") } && deictic.contains { padded.contains(" " + $0) }
        if let repo = c.defaultRepo, strong || weak, !mentionsSpreadsheet(lower) {
            return AskRoute(lane: .repo(path: repo), text: trimmed,
                            why: c.inCodeApp ? "a code question, from \(c.appName ?? "your editor")" : "sounds like a code question",
                            explicit: false)
        }

        // 4. Long or open-ended → the assistant you prefer, where a conversation can happen.
        let wordCount = lower.split(whereSeparator: \.isWhitespace).count
        if wordCount > 40 || openEnded.contains(where: { padded.contains($0) }) {
            return AskRoute(lane: .handoff(c.preferredHandoff), text: trimmed,
                            why: wordCount > 40 ? "long question" : "open-ended: better as a conversation", explicit: false)
        }

        // 5. Everything else: a quick answer, right here. Sure for clearly quick-shaped asks; otherwise the smarter
        //    router may check with a model when you press Return.
        return AskRoute(lane: .quick, text: trimmed, why: "short question", explicit: false, confident: looksQuick(lower))
    }

    /// Tab: quick → repo (if any) → preferred hand-off → the other assistants → quick.
    public static func next(after lane: AskLane, context c: AskContext) -> AskLane {
        var order: [AskLane] = [.quick]
        if let r = c.defaultRepo { order.append(.repo(path: r)) }
        order.append(.sessions)
        if c.browserTasks { order.append(.browser) }
        order.append(.handoff(c.preferredHandoff))
        order += AskLane.Provider.allCases.filter { $0 != c.preferredHandoff }.map { .handoff($0) }
        let i = order.firstIndex(of: lane) ?? -1
        return order[(i + 1) % order.count]
    }

    static let quickStarts = ["how do i ", "how to ", "how can i ", "what does ", "what is the ", "what's the ", "convert ",
                              "regex ", "shortcut ", "keyboard shortcut", "formula ", "command to ", "define ", "meaning of "]

    static func looksQuick(_ s: String) -> Bool {
        mentionsSpreadsheet(s) || quickStarts.contains { s.hasPrefix($0) }
            || ["formula", "terminal command", "shell command", "shortcut", "in excel", "in sheets"].contains { s.contains($0) }
    }

    static func mentionsSpreadsheet(_ s: String) -> Bool {
        ["sheet", "excel", "xlookup", "vlookup", "formula", "cell", "spreadsheet"].contains { s.contains($0) }
    }
}
