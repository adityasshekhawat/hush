import Foundation

/// The mail digest (ADR-027): instead of a visit per mail, Hush comes by at a natural break (back from being away, a
/// call ending), at most hourly, with what it held back since the last visit. Pure, so the counting is tested.
public struct MailDigest: Sendable, Equatable {
    public var total: Int
    /// Held back although the model thought they might need you (quiet hours, the daily cap), newest first.
    public var mightNeedYou: [(who: String, subject: String)]
    public var couldWait: Int
    public var bulk: Int

    public static func == (a: MailDigest, b: MailDigest) -> Bool {
        a.total == b.total && a.couldWait == b.couldWait && a.bulk == b.bulk
            && a.mightNeedYou.map { $0.who + $0.subject } == b.mightNeedYou.map { $0.who + $0.subject }
    }

    /// The address the digest's own card uses, so it never counts itself.
    public static let ownAddress = "digest@hush.local"
    /// Fewer than this held back: not worth a visit.
    public static let minimum = 3
    public static let interval: TimeInterval = 60 * 60

    /// From the journal: mail entries since the last digest that Hush didn't show.
    public static func build(_ entries: [LoggedDecision]) -> MailDigest? {
        let mail = entries.filter { $0.category.hasPrefix("mail:") && $0.category != "mail:" + ownAddress && $0.outcome != .shown }
        guard mail.count >= minimum else { return nil }
        let bulk = mail.filter { $0.outcome == .dropped }
        let held = mail.filter { $0.outcome != .dropped }
        let might = held.filter { $0.reasons.contains("model: gentle") || $0.reasons.contains("VIP") || $0.reasons.contains("rule: always") }
        return MailDigest(
            total: mail.count,
            mightNeedYou: might.prefix(3).map { (String($0.category.dropFirst(5)), $0.title ?? "") },
            couldWait: held.count - might.count,
            bulk: bulk.count)
    }

    /// "14 mails while you were busy"
    public var title: String { "\(total) \(total == 1 ? "mail" : "mails") while you were busy" }

    /// "2 might need you · 9 could wait · 3 newsletters"
    public var summary: String {
        var parts: [String] = []
        if !mightNeedYou.isEmpty { parts.append("\(mightNeedYou.count) might need you") }
        if couldWait > 0 { parts.append("\(couldWait) could wait") }
        if bulk > 0 { parts.append("\(bulk) \(bulk == 1 ? "newsletter" : "newsletters")") }
        return parts.joined(separator: " · ")
    }

    /// "priya@acme.io: Q4 plan" lines for the card.
    public var lines: String { mightNeedYou.map { "\($0.who): \($0.subject)" }.joined(separator: "\n") }
}
