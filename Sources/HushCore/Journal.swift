import Foundation

/// "What Hush saw" (ADR-026): every item Hush looked at, in plain words, kept on this Mac for 7 days. Pure, so the
/// wording is tested; the store holds the entries and the app shows them.
public enum Journal {
    public static let keepDays = 7

    /// Where it came from: "Mail from priya@acme.io", "Calendar", "Claude Code in hush".
    public static func source(_ e: LoggedDecision) -> String {
        let c = e.category
        if c.hasPrefix("mail:") { return "Mail from " + c.dropFirst(5) }
        if c == "meeting" { return "Calendar" }
        if c.hasPrefix("agent:") { return "Agent in " + c.dropFirst(6) }
        return c
    }

    /// What Hush did with it.
    public static func outcome(_ e: LoggedDecision) -> String {
        switch e.outcome {
        case .shown: return e.finalLevel == .interrupt ? "Came out for it" : "Showed it"
        case .ambient: return "Held it back"
        case .queued: return "Waited until you were free"
        case .dropped: return "Let it go"
        }
    }

    /// Why, in plain words, from the engine's reasons ("VIP | daily cap reached → gentle").
    public static func why(_ e: LoggedDecision) -> String {
        let parts = e.reasons.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.compactMap(phrase)
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        return unique.isEmpty ? "" : unique.joined(separator: ", ").prefix(1).uppercased() + unique.joined(separator: ", ").dropFirst()
    }

    static func phrase(_ r: String) -> String? {
        if r == "VIP" { return "on your VIP list" }
        if r == "bulk headers" { return "a newsletter or bulk mail" }
        if r == "meeting reminder" { return "a meeting is coming up" }
        if r.hasPrefix("computed in code") { return nil }
        if r == "rule: not this kind again" { return "your rule: hold these back" }
        if r.hasPrefix("rule: always") { return "your rule: always show these" }
        if r.hasPrefix("model: ") {
            let gentle = r.contains("gentle")
            let sure = (Double(r.split(separator: "@").last?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0) >= 0.7
            return gentle ? (sure ? "looked like it needs you" : "might need you") : (sure ? "could wait" : "probably could wait")
        }
        if r.hasPrefix("model can't interrupt") { return nil }
        if r.hasPrefix("low confidence") { return nil }
        if r.hasPrefix("shooed") { return "you shooed these before" }
        if r.hasPrefix("quiet hours") { return "quiet hours" }
        if r.hasPrefix("daily cap") { return "today's interrupts were used up" }
        if r.hasPrefix("busy") { return "you were busy" }
        return r
    }
}
