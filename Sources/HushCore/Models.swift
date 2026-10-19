import Foundation

/// The three rungs of the attention ladder (PRD § Attention ladder).
public enum AttentionLevel: Int, Sendable, Codable, Comparable, CaseIterable {
    case ambient = 0
    case gentle = 1
    case interrupt = 2

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .ambient: "ambient"
        case .gentle: "gentle"
        case .interrupt: "interrupt"
        }
    }

    /// One step down the ladder, bottoming out at ambient.
    public var lowered: AttentionLevel { AttentionLevel(rawValue: max(0, rawValue - 1)) ?? .ambient }
}

public enum ItemKind: String, Sendable, Codable {
    case mail
    case meeting
    /// A Claude Code session finished or needs you (docs/agent-plan.md, Phase 1).
    case agent
}

/// Something a source hands to the engine: a new mail, or a meeting reminder firing.
public struct InboxItem: Sendable, Equatable, Codable {
    public var id: String
    public var kind: ItemKind
    public var senderName: String?
    public var senderAddress: String?
    public var subject: String
    /// Short plain-text snippet. Never leaves the Mac by default.
    public var snippet: String
    /// Raw mail headers, lowercased keys. Empty for meetings.
    public var headers: [String: String]
    public var receivedAt: Date
    /// For meeting reminders: when the meeting starts.
    public var startsAt: Date?
    /// Deep link for the "Open" action (message:// or ical://).
    public var openURL: URL?
    /// Agent items: bundle id of the app hosting the session (Open brings it forward) and the project folder name.
    public var sourceApp: String?
    public var project: String?

    public init(
        id: String, kind: ItemKind, senderName: String? = nil, senderAddress: String? = nil,
        subject: String, snippet: String = "", headers: [String: String] = [:],
        receivedAt: Date, startsAt: Date? = nil, openURL: URL? = nil, sourceApp: String? = nil, project: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.senderName = senderName
        self.senderAddress = senderAddress?.lowercased()
        self.subject = subject
        self.snippet = snippet
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
        self.receivedAt = receivedAt
        self.startsAt = startsAt
        self.openURL = openURL
        self.sourceApp = sourceApp
        self.project = project
    }

    public var senderDomain: String? {
        guard let a = senderAddress, let at = a.lastIndex(of: "@") else { return nil }
        return String(a[a.index(after: at)...])
    }

    /// The "type" that shoos and "Not this kind again" act on.
    /// Mail groups by sender; meeting reminders form one type.
    public var category: String {
        switch kind {
        case .mail: "mail:" + (senderAddress ?? "unknown")
        case .meeting: "meeting"
        case .agent: "agent:" + (project ?? "unknown")
        }
    }
}

/// What the classifier (step 2 of the cascade) says about an item.
public struct Classification: Sendable, Equatable {
    public var level: AttentionLevel
    /// 0...1. Below the engine's threshold, the result is treated as unsure.
    public var confidence: Double
    public var modelVersion: String

    public init(level: AttentionLevel, confidence: Double, modelVersion: String) {
        self.level = level
        self.confidence = min(1, max(0, confidence))
        self.modelVersion = modelVersion
    }
}

/// What the user is doing right now (FR-7).
public struct UserFocus: Sendable, Equatable {
    public var inCall: Bool
    public var screenSharing: Bool
    public var fullScreen: Bool
    public var typing: Bool
    /// No keyboard or mouse input for a while: the only time Hush dozes off.
    public var away: Bool
    /// You paused Hush (menu bar or ⌥⇧⌘H): gone until the pause ends, things queue (ADR-022).
    public var paused: Bool
    /// The screen is locked or asleep: nothing to show, so nothing renders.
    public var locked: Bool

    public init(inCall: Bool = false, screenSharing: Bool = false, fullScreen: Bool = false, typing: Bool = false,
                away: Bool = false, paused: Bool = false, locked: Bool = false) {
        self.inCall = inCall
        self.screenSharing = screenSharing
        self.fullScreen = fullScreen
        self.typing = typing
        self.away = away
        self.paused = paused
        self.locked = locked
    }

    public static let idle = UserFocus()

    /// Hidden entirely: calls, screen shares, full-screen work.
    public var hidesCharacter: Bool { inCall || screenSharing || fullScreen || paused || locked }
    /// Anything that should hold back a gentle or interrupt appearance.
    public var isBusy: Bool { hidesCharacter || typing }
}
