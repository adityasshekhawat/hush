import Foundation

/// "Hand it to Hush" (ADR-019): copy text, Hush's cheeks fill; click Hush, pick a verb, Hush chews and hands back
/// the reworked text on the clipboard; paste. Pure, so the verbs, limits, prompt and cleanup are tested; the model
/// call is `OnDeviceRewriter` (HushMac) and runs on this Mac.
public enum PouchVerb: String, CaseIterable, Sendable, Codable {
    case simpler, shorter, bullets

    public var title: String {
        switch self {
        case .simpler: "Simpler"
        case .shorter: "Shorter"
        case .bullets: "Bullets"
        }
    }

    public var symbol: String {
        switch self {
        case .simpler: "leaf"
        case .shorter: "scissors"
        case .bullets: "list.bullet"
        }
    }

    /// The receipt once it's on the clipboard.
    public var done: String {
        switch self {
        case .simpler: "Simpler version ready"
        case .shorter: "Shorter version ready"
        case .bullets: "Bullets ready"
        }
    }

    var task: String {
        switch self {
        case .simpler: "Rewrite it in plain, simple words that anyone could follow. Use short sentences. Keep every fact."
        case .shorter: "Cut it to about half the words. Drop pleasantries, filler and repetition. Keep the key points, the facts and anything that's asked of the reader."
        case .bullets: "Turn it into a short list of bullet points, one idea per line, each line starting with \"- \"."
        }
    }
}

public enum Pouch {
    /// About 1,500 tokens in, leaving room for the answer in the on-device model's 4,096-token context.
    public static let maxCharacters = 6000

    public enum Check: Equatable, Sendable {
        case ok(String)
        /// Nothing to rework: no text on the clipboard (an image or a file), or only whitespace.
        case empty
        /// More than the model can take at once.
        case tooLong(Int)
        /// Code: the writing verbs would break it (a "shorter" function squashed onto one line), so Hush leaves it.
        case code
    }

    public static func check(_ text: String?) -> Check {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), t.count >= 2 else { return .empty }
        if t.count > maxCharacters { return .tooLong(t.count) }
        return looksLikeCode(t) ? .code : .ok(t)
    }

    /// Several lines that read like a program: braces or semicolons at line ends, keywords, arrows, indentation.
    static func looksLikeCode(_ t: String) -> Bool {
        let lines = t.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 2 else { return false }
        let keywords = ["func ", "def ", "class ", "return ", "import ", "const ", "let ", "var ", "if (", "for (", "} else", "#include", "public ", "fn "]
        let codeish = lines.filter { l in
            ["{", "}", ";", "):", "=>", "->"].contains { l.hasSuffix($0) } || keywords.contains { l.hasPrefix($0) }
                || l == "}" || l.hasPrefix("//") || l.hasPrefix("# ")
        }
        return Double(codeish.count) / Double(lines.count) >= 0.4
    }

    public static let instructions = """
        You rework text the reader copied. Keep the meaning, names, numbers, dates and links, and write in the same \
        language and voice as the original. Never add facts, greetings or comments about the text. \
        Return only the reworked text.
        """

    public static let resultField = "text"
    public static let resultGuide = "The reworked text only, ready to paste."

    public static func prompt(_ text: String, verb: PouchVerb) -> String {
        "\(verb.task)\n\nText:\n\(text)"
    }

    /// The model's answer, tidied for pasting, or nil when there's nothing usable (empty, or unchanged).
    public static func clean(_ raw: String, verb: PouchVerb, original: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A code fence or quotes wrapped around the whole answer.
        if s.hasPrefix("```"), s.hasSuffix("```"), s.count > 6 {
            s = String(s.dropFirst(3).dropLast(3))
            if let nl = s.firstIndex(of: "\n"), !s[..<nl].contains(" ") { s = String(s[s.index(after: nl)...]) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (open, close) in [("\"", "\""), ("“", "”")] where s.hasPrefix(open) && s.hasSuffix(close) && s.count > 2 {
            let inner = s.dropFirst().dropLast()
            if !inner.contains(open) && !inner.contains(close) { s = String(inner) }
        }
        if verb == .bullets {
            s = s.split(separator: "\n", omittingEmptySubsequences: true).map { line -> String in
                var l = line.trimmingCharacters(in: .whitespaces)
                for mark in ["• ", "* ", "– ", "— ", "· "] where l.hasPrefix(mark) { l = "- " + l.dropFirst(mark.count) }
                if l.hasPrefix("-"), !l.hasPrefix("- ") { l = "- " + l.dropFirst() }
                if l.hasPrefix("- "), let first = l.dropFirst(2).first, first.isLowercase {
                    l = "- " + first.uppercased() + l.dropFirst(3)
                }
                return l
            }.joined(separator: "\n")
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s != original.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return s
    }

    /// What goes to your assistant when the on-device model can't help (off, or too long): the verb and the text.
    public static func handoffQuestion(_ text: String, verb: PouchVerb) -> String {
        "\(verb.task)\n\n\(text)"
    }
}
