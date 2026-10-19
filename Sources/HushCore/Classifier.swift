import Foundation

/// Step 2 of the cascade. Implementations: rules-only (here), Apple Foundation Models (macOS 26, later),
/// an MLX model with real answer probabilities, or a user-connected cloud model.
public protocol AttentionClassifier: Sendable {
    var version: String { get }
    /// Called only for items the hard rules couldn't settle. Must not block the character.
    func classify(_ item: InboxItem) async -> Classification
}

/// Step 3 of the cascade: the one-line gist shown on the envelope card (FR-9).
public protocol GistWriter: Sendable {
    func gist(for item: InboxItem) async -> String
}

/// FR-14: what runs on Macs without Apple Intelligence (and on this dev machine, which is on macOS 15).
/// Deliberately timid: it never returns interrupt and rarely claims confidence.
public struct RulesOnlyClassifier: AttentionClassifier {
    public let version = "rules-1"

    /// Words that suggest a person needs something from you. Kept short on purpose.
    static let askSignals = [
        "urgent", "asap", "today", "deadline", "action required", "can you", "could you",
        "please review", "approve", "approval", "blocked", "eod", "by tomorrow",
    ]

    public init() {}

    public func classify(_ item: InboxItem) async -> Classification {
        let text = (item.subject + " " + item.snippet).lowercased()
        let asks = Self.askSignals.contains { text.contains($0) }
        let isReply = item.subject.lowercased().hasPrefix("re:")
        let level: AttentionLevel = (asks || isReply) ? .gentle : .ambient
        // Heuristics are never sure. 0.6 sits below the default 0.7 threshold, so the engine
        // treats every heuristic call as "unsure", which is exactly the PRD's intent for rules-only mode.
        return Classification(level: level, confidence: 0.6, modelVersion: version)
    }
}

/// Fallback gist: sender plus a cleaned-up subject. Instant, no model.
public struct SubjectGistWriter: GistWriter {
    public init() {}

    public func gist(for item: InboxItem) async -> String {
        if item.kind == .agent { return item.snippet }
        let who = item.senderName ?? item.senderAddress ?? "Someone"
        var subject = item.subject
        while let r = subject.range(of: #"^\s*(re|fwd?|aw):\s*"#, options: [.regularExpression, .caseInsensitive]) {
            subject.removeSubrange(r)
        }
        let line = subject.isEmpty ? item.snippet : subject
        return "\(who): \(line.prefix(90))"
    }
}

/// FR-3: drop bulk mail from headers alone, before any model call.
public enum BulkMailFilter {
    public static func isBulk(_ item: InboxItem) -> Bool {
        guard item.kind == .mail else { return false }
        let h = item.headers
        if h["list-unsubscribe"] != nil || h["list-id"] != nil { return true }
        if let p = h["precedence"]?.lowercased(), ["bulk", "list", "junk"].contains(p) { return true }
        if let a = h["auto-submitted"]?.lowercased(), a != "no" { return true }
        if let addr = item.senderAddress {
            let local = addr.split(separator: "@").first.map(String.init) ?? ""
            if ["noreply", "no-reply", "donotreply", "do-not-reply", "notifications", "mailer-daemon"].contains(local) {
                return true
            }
        }
        return false
    }
}
