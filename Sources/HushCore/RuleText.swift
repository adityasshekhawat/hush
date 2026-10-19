import Foundation

/// Rules as first-person sentences (docs/design-guide.md §5.3): the rule is stored as structured data, the sentence
/// is generated from it, and an edited sentence is parsed back in code. Unparseable edits keep the old rule.
public enum RuleText {
    /// "I'll hold back mail from news@shop.com."
    public static func sentence(_ rule: UserRule) -> String {
        "\(verb(rule.action)) \(subject(rule.match))."
    }

    static func verb(_ action: UserRule.Action) -> String {
        switch action {
        case .never: "I'll hold back"
        case .alwaysGentle: "I'll always show you"
        case .alwaysInterrupt: "I'll always tap the glass for"
        }
    }

    static func subject(_ match: UserRule.Match) -> String {
        switch match {
        case .sender(let s): return "mail from \(s)"
        case .senderDomain(let d): return "mail from anyone at \(d)"
        case .subjectContains(let w): return "mail about “\(w)”"
        case .category(let c):
            if c == "meeting" { return "meeting reminders" }
            if c.hasPrefix("agent:") { return "agent updates in \(c.dropFirst(6))" }
            if c.hasPrefix("mail:") { return "mail from \(c.dropFirst(5))" }
            return c
        }
    }

    /// Parse an edited sentence back into a rule (keeping `base`'s id and date). nil when it doesn't follow.
    public static func parse(_ text: String, base: UserRule) -> UserRule? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        let lower = t.lowercased()
        let verbs: [(String, UserRule.Action)] = [
            ("i'll always tap the glass for ", .alwaysInterrupt), ("always tap the glass for ", .alwaysInterrupt),
            ("i'll always interrupt for ", .alwaysInterrupt), ("always interrupt for ", .alwaysInterrupt),
            ("i'll always show you ", .alwaysGentle), ("always show me ", .alwaysGentle), ("always show ", .alwaysGentle),
            ("i'll hold back ", .never), ("hold back ", .never), ("never show ", .never), ("hide ", .never),
        ]
        guard let (prefix, action) = verbs.first(where: { lower.hasPrefix($0.0) }) else { return nil }
        let rest = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let r = rest.lowercased()
        let match: UserRule.Match
        if r == "meeting reminders" || r == "meetings" {
            match = .category("meeting")
        } else if r.hasPrefix("mail from anyone at ") {
            let d = String(r.dropFirst("mail from anyone at ".count)).trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
            guard isDomain(d) else { return nil }
            match = .senderDomain(d)
        } else if r.hasPrefix("mail from ") || r.hasPrefix("emails from ") {
            let who = String(r.drop(while: { $0 != " " }).dropFirst(" from ".count - 1)).trimmingCharacters(in: .whitespaces)
            if who.hasPrefix("@") || (!who.contains("@") && isDomain(who)) {
                let d = who.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                guard isDomain(d) else { return nil }
                match = .senderDomain(d)
            } else {
                guard isAddress(who) else { return nil }
                match = .sender(who)
            }
        } else if r.hasPrefix("mail about ") {
            // "mail about invoice" or “invoice”: a word or short phrase in the subject (ADR-027).
            let w = String(rest.dropFirst("mail about ".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”' ").union(.whitespaces))
            guard (2...40).contains(w.count), w.split(separator: " ").count <= 4 else { return nil }
            match = .subjectContains(w.lowercased())
        } else if r.hasPrefix("agent updates in ") {
            let project = String(rest.dropFirst("agent updates in ".count)).trimmingCharacters(in: .whitespaces)
            guard !project.isEmpty, !project.contains(" ") else { return nil }
            match = .category("agent:" + project)
        } else {
            return nil
        }
        var rule = base
        rule.match = match
        rule.action = action
        return rule
    }

    static func isAddress(_ s: String) -> Bool {
        s.range(of: #"^[^@\s]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }

    static func isDomain(_ s: String) -> Bool {
        s.range(of: #"^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }
}

/// "Tell Hush what matters" (ADR-026): Apple's on-device model turns plain words into rule sentences in RuleText's own
/// grammar; each is parsed in code and only becomes a rule when you add it. The model never decides anything itself.
public enum RuleSuggestions {
    public static let instructions = """
        Turn what the reader says matters into rules for a quiet desktop companion. Write each rule as one sentence, \
        using exactly one of these forms:
        Always show me mail from <email address>
        Always show me mail from anyone at <domain>
        Always tap the glass for mail from <email address>
        Always tap the glass for mail from anyone at <domain>
        Hold back mail from <email address>
        Hold back mail from anyone at <domain>
        Always show me mail about <word in the subject>
        Always tap the glass for mail about <word in the subject>
        Always tap the glass for meeting reminders
        Hold back agent updates in <project folder name>
        Use only addresses, domains and project names the reader actually wrote. If they mention a person or a kind of \
        mail without an address or a domain, skip it. Write at most 5 rules.
        """

    public static let maxRules = 5

    /// The model's sentences as rules, in order, without ones that don't parse or repeat.
    public static func rules(from sentences: [String], now: Date) -> [UserRule] {
        var out: [UserRule] = []
        for s in sentences.prefix(maxRules * 2) {
            let base = UserRule(match: .category("meeting"), action: .never, createdAt: now)
            guard let r = RuleText.parse(tidy(s), base: base),
                  !out.contains(where: { $0.match == r.match && $0.action == r.action }) else { continue }
            out.append(r)
            if out.count == maxRules { break }
        }
        return out
    }

    /// The model sometimes keeps the form's wording: "agent updates in scratch project folder" → "in scratch".
    static func tidy(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))
        for tail in [" project folder", " project", " folder", " repo", " repository"] where t.lowercased().hasSuffix(tail) {
            t = String(t.dropLast(tail.count))
        }
        return t
    }
}
