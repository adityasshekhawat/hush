import Foundation

/// A quick-lane answer, shaped for its card (docs/ask-design.md § Answer shapes).
public struct AnswerShape: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable, CaseIterable { case formula, command, fact, steps, prose }

    public struct Part: Sendable, Equatable, Codable {
        public var label: String
        public var detail: String
        public init(label: String, detail: String) { self.label = label; self.detail = detail }
    }

    public var shape: Kind
    /// Short heading, e.g. "XLOOKUP in Google Sheets".
    public var title: String
    /// The thing to copy: the formula, the command, the one-line fact, or the prose answer.
    public var primary: String
    /// Formula arguments / command flags / steps.
    public var parts: [Part]
    /// For formulas: which app's syntax ("Google Sheets", "Excel"). For commands: the shell or tool.
    public var app: String?
    /// One supporting line: an example, a caveat, or a warning for destructive commands.
    public var note: String?
    public var destructive: Bool

    public init(shape: Kind, title: String, primary: String, parts: [Part] = [], app: String? = nil,
                note: String? = nil, destructive: Bool = false) {
        self.shape = shape
        self.title = title
        self.primary = primary
        self.parts = parts
        self.app = app
        self.note = note
        self.destructive = destructive
    }

    enum CodingKeys: String, CodingKey { case shape, title, primary, parts, app, note, destructive }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shape = (try? c.decode(Kind.self, forKey: .shape)) ?? .prose
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        primary = (try? c.decode(String.self, forKey: .primary)) ?? ""
        parts = (try? c.decode([Part].self, forKey: .parts)) ?? []
        app = try? c.decode(String.self, forKey: .app)
        note = try? c.decode(String.self, forKey: .note)
        destructive = (try? c.decode(Bool.self, forKey: .destructive)) ?? false
    }

    /// JSON Schema handed to the model (claude --json-schema).
    public static let jsonSchema = """
        {"type":"object","additionalProperties":false,"required":["shape","title","primary"],"properties":{\
        "shape":{"type":"string","enum":["formula","command","fact","steps","prose"]},\
        "title":{"type":"string","description":"Short heading, under 8 words"},\
        "primary":{"type":"string","description":"formula: the full formula. command: the exact command. fact: ONLY the answer, 1-6 words, e.g. '236.6 mL' (context goes in note). steps: one-line summary. prose: 2-5 sentences, inline markdown allowed"},\
        "parts":{"type":"array","maxItems":8,"items":{"type":"object","additionalProperties":false,"required":["label","detail"],\
        "properties":{"label":{"type":"string"},"detail":{"type":"string"}}},\
        "description":"formula: each argument. command: key flags. steps: each step (label = short action, detail = how)."},\
        "app":{"type":"string","description":"formula: whose syntax (Google Sheets, Excel, Numbers). command: shell or tool."},\
        "note":{"type":"string","description":"One line: a concrete example, a caveat, or a warning"},\
        "destructive":{"type":"boolean","description":"true if running the command can lose data"}}}
        """

    public static let systemPrompt = """
        You answer quick practical questions for Hush, a small desktop companion. Pick the shape that fits: formula \
        (spreadsheet formulas), command (terminal/git/CLI), fact (a short factual answer), steps (how to do something \
        in an app), prose (anything else). Be correct and brief. If the user didn't say which spreadsheet app, use the \
        app they're in if it's a spreadsheet, else Google Sheets syntax, and say so in note. Never invent functions.
        """

    /// Text for Copy and for handing the answer to another assistant.
    public var plainText: String {
        var s = primary
        if !parts.isEmpty {
            s += "\n" + parts.map { "• \($0.label): \($0.detail)" }.joined(separator: "\n")
        }
        if let note { s += "\n\(note)" }
        return s
    }
}
