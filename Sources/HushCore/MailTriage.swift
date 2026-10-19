import Foundation

/// What Hush asks Apple's on-device model about one mail (cascade steps 2 and 3 in one call: level, sureness, gist),
/// and how it reads the answer. Pure, so the prompt and the parsing are tested; the model call lives in HushMac
/// (`OnDeviceTriage`). Only sender, subject and a short snippet are sent, and the model runs on this Mac (PRD § AI).
public enum MailTriage {
    public static let version = "on-device-1"

    public static let instructions = """
        You sort incoming email for a quiet desktop companion. Most mail can wait. Choose "gentle" only when a real \
        person needs a reply, a decision or an action from the reader soon, or something the reader owns is broken. \
        Newsletters, promotions, receipts, shipping updates, automated notifications and FYIs are "ambient". \
        Calendar invitations and updates are ambient too: the companion reads the calendar itself. \
        When a person asks the reader to reply, call, join, confirm or decide, it's gentle, even when it's short or \
        casual ("coffee later?", "ring me tonight"), and especially when it's happening now. \
        Say sure only when the sender and subject make the choice obvious.
        """

    /// Field names and guidance for the structured answer (built into a schema in HushMac).
    public enum Field {
        public static let level = "level"
        public static let sure = "sure"
        public static let gist = "gist"
        public static let levels = ["ambient", "gentle"]
        public static let levelGuide = "ambient: fine to see later. gentle: a person needs something from the reader soon."
        public static let sureGuide = "true only if the choice is obvious from the sender and subject"
        public static let gistGuide = """
            One short plain line, under 60 characters, starting with a verb about the sender, like "Asks if you're \
            free for lunch tomorrow at 1" or "Needs your signature by Friday". Don't repeat the subject, don't name \
            the sender, no quotes, no full stop.
            """
    }

    static let maxSubject = 200
    static let maxSnippet = 400
    public static let maxGist = 90

    public static func prompt(for item: InboxItem) -> String {
        let who = [item.senderName, item.senderAddress.map { "<\($0)>" }].compactMap { $0 }.joined(separator: " ")
        return """
            From: \(who.isEmpty ? "unknown" : who)
            Subject: \(clip(item.subject, maxSubject))
            Snippet: \(clip(item.snippet, maxSnippet))
            """
    }

    /// The model's answer as a cascade classification. Unknown levels read as ambient (when unsure, stay quiet).
    /// "Sure" lands above the engine's default 0.7 threshold, "not sure" below it, matching ADR-003's reading.
    public static func classification(level: String, sure: Bool) -> Classification {
        let l: AttentionLevel = level.lowercased().trimmingCharacters(in: .whitespaces) == "gentle" ? .gentle : .ambient
        return Classification(level: l, confidence: sure ? 0.85 : 0.6, modelVersion: version)
    }

    /// One tidy line, or nil when there's nothing worth showing (the card then falls back to the plain gist).
    public static func cleanGist(_ raw: String) -> String? {
        var s = raw.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’")))
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        guard s.count >= 3 else { return nil }
        if s.count > maxGist {
            let cut = s.prefix(maxGist - 1)
            s = (cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)) + "…"
        }
        while s.hasSuffix(".") && !s.hasSuffix("...") { s.removeLast() }
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    static func clip(_ s: String, _ n: Int) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return flat.count > n ? String(flat.prefix(n)) + "…" : flat
    }
}

/// The meeting context line at T-5 (ADR-025): one short line from the invite's notes, on Apple's on-device model.
/// Only the title and trimmed notes go in (MeetingLinks.trimNotes drops links and dial-in text); nothing is stored.
public enum MeetingContext {
    public static let instructions = """
        You write one short line for a meeting reminder card, from the invite's notes: the topic, and anything to \
        prepare or bring. Under 60 characters, plain words, no quotes, no full stop, no names of the people invited. \
        If the notes say nothing useful, reply with an empty line.
        """

    public static func prompt(title: String, notes: String) -> String { "Meeting: \(title)\nNotes: \(notes)" }
}
