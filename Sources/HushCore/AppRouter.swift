import Foundation

/// App router R0 (docs/app-router-plan.md): the answer goes where you work. Pure, so ranking is testable.

/// Apps Hush can send an answer to. Bundle ids are what macOS reports for the frontmost app.
public enum AppTarget: String, Sendable, CaseIterable {
    case excel, googleSheets, warp, terminal, iterm, cursor, notion, obsidian

    public var displayName: String {
        switch self {
        case .excel: "Excel"
        case .googleSheets: "Google Sheets"
        case .warp: "Warp"
        case .terminal: "Terminal"
        case .iterm: "iTerm"
        case .cursor: "Cursor"
        case .notion: "Notion"
        case .obsidian: "Obsidian"
        }
    }

    /// nil for web-only targets.
    public var bundleID: String? {
        switch self {
        case .excel: "com.microsoft.Excel"
        case .googleSheets: nil
        case .warp: "dev.warp.Warp-Stable"
        case .terminal: "com.apple.Terminal"
        case .iterm: "com.googlecode.iterm2"
        case .cursor: "com.todesktop.230313mzl4w4u92"
        case .notion: "notion.id"
        case .obsidian: "md.obsidian"
        }
    }

    public static func from(bundleID: String?) -> AppTarget? {
        allCases.first { $0.bundleID != nil && $0.bundleID == bundleID }
    }

    static let terminals: [AppTarget] = [.warp, .iterm, .terminal]
}

/// How an action reaches the app (cheapest first; R0 uses only the permission-free rungs).
public enum ActionMechanism: Sendable, Equatable {
    /// Copy the text, then bring the app forward (launching it if needed). You press ⌘V.
    case copyAndActivate(bundleID: String)
    /// Copy the text, then open a URL (a deep link or a web page).
    case copyAndOpen(URL)
    /// Hand the question to an assistant (Ask Hush "Continue in…").
    case continueIn(AskLane.Provider)
    /// Just copy.
    case copy
}

public struct AppAction: Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var symbol: String
    public var mechanism: ActionMechanism
    /// Shown after the action runs, e.g. "Copied. Press ⌘V in Excel."
    public var receipt: String
    /// The target app, for its icon on the button (nil for Copy / assistants).
    public var target: AppTarget?
}

/// What kind of answer is on the card.
public enum AnswerKind: Sendable, Equatable {
    case formula, command, fact, steps, prose
    /// A read-only repo answer (code question).
    case repo

    public init(_ shape: AnswerShape.Kind) {
        switch shape {
        case .formula: self = .formula
        case .command: self = .command
        case .fact: self = .fact
        case .steps: self = .steps
        case .prose: self = .prose
        }
    }
}

public struct ActionContext: Sendable {
    public var kind: AnswerKind
    /// The app you were in when you asked.
    public var frontmostApp: String?
    /// Bundle ids of apps installed on this Mac (targets that aren't installed are never offered).
    public var installed: Set<String>
    public var preferredHandoff: AskLane.Provider
    /// The question (for prompts sent to Cursor) and the answer text being sent.
    public var question: String
    public var answer: String

    public init(kind: AnswerKind, frontmostApp: String?, installed: Set<String>, preferredHandoff: AskLane.Provider = .chatgpt,
                question: String = "", answer: String = "") {
        self.kind = kind
        self.frontmostApp = frontmostApp
        self.installed = installed
        self.preferredHandoff = preferredHandoff
        self.question = question
        self.answer = answer
    }

    func has(_ t: AppTarget) -> Bool { t.bundleID.map(installed.contains) ?? true }
    var from: AppTarget? { AppTarget.from(bundleID: frontmostApp) }
}

public enum ActionRanker {
    /// Up to three actions, primary first (docs/app-router-plan.md § The action row). Copy is always one of them.
    public static func actions(for c: ActionContext) -> [AppAction] {
        var picks: [AppAction] = []
        let from = c.from

        switch c.kind {
        case .formula:
            if from == .excel { picks.append(paste(.excel)) }
            if from != .excel, c.has(.excel) { picks.append(open(.excel, title: "Open in Excel")) }
            picks.append(newSheet)

        case .command:
            let terminal = from.flatMap { AppTarget.terminals.contains($0) ? $0 : nil }
                ?? AppTarget.terminals.first(where: c.has)
            if let t = terminal { picks.append(send(t)) }

        case .repo:
            if c.has(.cursor) { picks.append(askCursor(c)) }

        case .steps, .prose, .fact:
            if from == .notion, c.has(.notion) { picks.append(saveNotion) }
            if from == .obsidian, c.has(.obsidian) { picks.append(saveObsidian(c)) }
            if from == .cursor, c.has(.cursor), c.kind != .fact { picks.append(askCursor(c)) }
        }

        // Copy is always there: primary when nothing app-specific fits, otherwise second.
        let copy = AppAction(id: "copy", title: "Copy", symbol: "doc.on.doc", mechanism: .copy, receipt: "Copied", target: nil)
        if picks.isEmpty { picks.append(copy) } else { picks.insert(copy, at: min(1, picks.count)) }

        // Room left: carry on in your assistant.
        // Short label (three buttons share 390 pt); the tooltip and receipt say "Continue in…".
        picks.append(AppAction(id: "continue", title: c.preferredHandoff.displayName, symbol: "arrow.up.forward.app",
                               mechanism: .continueIn(c.preferredHandoff), receipt: "Continue in \(c.preferredHandoff.displayName) with this answer", target: nil))
        return Array(dedupe(picks).prefix(3))
    }

    // MARK: actions

    static func paste(_ t: AppTarget) -> AppAction {
        AppAction(id: "paste.\(t.rawValue)", title: "Paste in \(t.displayName)", symbol: "arrow.down.doc",
                  mechanism: .copyAndActivate(bundleID: t.bundleID!), receipt: "Copied. Press ⌘V in \(t.displayName).", target: t)
    }

    static func open(_ t: AppTarget, title: String) -> AppAction {
        AppAction(id: "open.\(t.rawValue)", title: title, symbol: "arrow.up.right.square",
                  mechanism: .copyAndActivate(bundleID: t.bundleID!), receipt: "Copied. Press ⌘V in \(t.displayName).", target: t)
    }

    static func send(_ t: AppTarget) -> AppAction {
        AppAction(id: "send.\(t.rawValue)", title: "Send to \(t.displayName)", symbol: "terminal",
                  mechanism: .copyAndActivate(bundleID: t.bundleID!),
                  receipt: "Copied. Press ⌘V in \(t.displayName), check it, then Return.", target: t)
    }

    static let newSheet = AppAction(id: "open.sheets", title: "New Google Sheet", symbol: "tablecells",
                                    mechanism: .copyAndOpen(URL(string: "https://sheets.new")!),
                                    receipt: "Copied. Click a cell and press ⌘V.", target: .googleSheets)

    static let saveNotion = AppAction(id: "save.notion", title: "Save to Notion", symbol: "square.and.arrow.down",
                                      mechanism: .copyAndActivate(bundleID: AppTarget.notion.bundleID!),
                                      receipt: "Copied. Press ⌘V in a Notion page.", target: .notion)

    /// Obsidian's documented new-note link. Copied first, so a paste still works if the link doesn't land.
    static func saveObsidian(_ c: ActionContext) -> AppAction {
        let name = String(c.question.prefix(60)).replacingOccurrences(of: "/", with: "-")
        let url = URL(string: "obsidian://new?name=\(enc("Hush – " + name))&content=\(enc(c.answer))")
            ?? URL(string: "obsidian://open")!
        return AppAction(id: "save.obsidian", title: "Save to Obsidian", symbol: "square.and.arrow.down",
                         mechanism: .copyAndOpen(url), receipt: "Saved as a new note (also copied).", target: .obsidian)
    }

    /// Cursor's documented prompt link: opens Cursor's chat pre-filled; you review and confirm there.
    static func askCursor(_ c: ActionContext) -> AppAction {
        let prompt = "\(c.question)\n\nContext from Hush:\n\(c.answer.prefix(6000))"
        let url = URL(string: "cursor://anysphere.cursor-deeplink/prompt?text=\(enc(prompt))")!
        return AppAction(id: "ask.cursor", title: "Ask Cursor", symbol: "chevron.left.forwardslash.chevron.right",
                         mechanism: .copyAndOpen(url), receipt: "Opened in Cursor. Review the prompt there.", target: .cursor)
    }

    static func enc(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    static func dedupe(_ a: [AppAction]) -> [AppAction] {
        var seen = Set<String>()
        return a.filter { seen.insert($0.id).inserted }
    }
}
