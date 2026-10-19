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
