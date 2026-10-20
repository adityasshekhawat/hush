import Foundation

/// The 9 poses in the character pack. Raw values match `assets/character/states/{body}/NN-name.svg`.
/// These are also the planned Rive state-machine states.
public enum CharacterState: String, Sendable, CaseIterable {
    case peek = "01-peek"
    case doze = "02-doze"
    case pile = "03-pile"
    case hold = "04-hold"
    case clock = "05-clock"
    case hurry = "06-hurry"
    case tap = "07-tap"
    case bow = "08-bow"
    case hide = "09-hide"
    /// A Claude Code session is working while you're elsewhere (ambient).
    case think = "10-think"
    /// Something needs you (an agent is waiting on a permission prompt).
    case notice = "11-notice"
    /// Standing, attentive: used while Hush guides you through onboarding.
    case stand = "12-stand"

}

/// Inputs the character's pose depends on. Pure data, so the mapping is testable and portable.
public struct PresenceInput: Sendable {
    public var focus: UserFocus
    /// The appearance waiting for a click, if any.
    public var active: Decision?
    public var ambientPile: Int
    public var nextMeetingStart: Date?
    public var now: Date
    public var justShooed: Bool
    /// One of your Claude Code sessions is working somewhere you're not looking.
    public var agentWorking: Bool

    public init(focus: UserFocus = .idle, active: Decision? = nil, ambientPile: Int = 0,
                nextMeetingStart: Date? = nil, now: Date = Date(), justShooed: Bool = false, agentWorking: Bool = false) {
        self.focus = focus
        self.active = active
        self.ambientPile = ambientPile
        self.nextMeetingStart = nextMeetingStart
        self.now = now
        self.justShooed = justShooed
        self.agentWorking = agentWorking
    }
}

public enum Presence {
    /// Pile shows once this many ambient items have stacked up.
    public static let pileThreshold = 3
    /// Won't doze off with a meeting this close.
    public static let dozeWindow: TimeInterval = 30 * 60

    public static func state(for p: PresenceInput) -> CharacterState {
        if p.justShooed { return .bow }
        // Calls / full-screen: hide (the app also removes the window). Typing: duck into the same pose,
        // "only the top of the head visible (user is busy)", and stay visible.
        if p.focus.hidesCharacter || p.focus.typing { return .hide }
        if let a = p.active, a.outcome == .shown, let level = a.finalLevel {
            switch (level, a.item.kind) {
            case (.interrupt, _): return .hurry
            case (.gentle, .meeting): return .clock
            case (.gentle, .mail): return .hold
            case (.gentle, .agent): return a.item.id.contains(":approval:") ? .notice : .hold
            case (.ambient, _): break
            }
        }
        if p.agentWorking { return .think }
        if p.ambientPile >= pileThreshold { return .pile }
        // Default is sneak mode: peeking over the screen edge. It only dozes while you're away
        // and nothing is coming up soon ("Peeks from the screen edge, blinks, occasionally dozes").
        let meetingSoon = p.nextMeetingStart.map { $0.timeIntervalSince(p.now) < dozeWindow } ?? false
        if p.focus.away && !meetingSoon { return .doze }
        return .peek
    }
}

/// What Hush holds up for the thing it's showing (v1 art, ADR-030): the renderer's variant of a state, and the words
/// its art shows (the art never bakes text in). nil `name`: the state's own pose.
public struct CharacterVariant: Equatable, Sendable {
    public var name: String?
    public var labels: [String: String]

    public init(_ name: String? = nil, labels: [String: String] = [:]) {
        self.name = name
        self.labels = labels
    }

    public static func of(state: CharacterState, active: Decision?, now: Date) -> CharacterVariant {
        guard let a = active, a.outcome == .shown else { return .init() }
        let item = a.item
        switch item.kind {
        case .agent:
            if item.id.contains(":approval:") {
                return item.id.hasSuffix(":risky") ? .init("careful", labels: ["card": "Look carefully"]) : .init("needs")
            }
            return item.id.contains(":error:") ? .init("error") : .init()
        case .meeting:
            switch state {
            case .clock: return .init("meeting", labels: ["card": short(item.subject)])
            case .hurry, .tap: return .init(item.startsAt.map { $0 <= now } == true ? "late" : "door")
            default: return .init()
            }
        case .mail:
            return state == .hurry || state == .tap ? .init("mail") : .init()
        }
    }

    /// Six words or fewer fit the card.
    static func short(_ s: String) -> String {
        let words = s.split(whereSeparator: \.isWhitespace)
        return words.prefix(6).joined(separator: " ") + (words.count > 6 ? "…" : "")
    }
}

/// The flag rail (v1 art, ADR-030): agent sessions waiting behind the one Hush holds, as flags planted on the bottom
/// edge, newest nearest Hush. At most 5; from the 6th, the oldest ones fold into one "+N more" bundle.
public enum FlagRail {
    public enum Kind: String, Sendable { case done, needs, careful, error }

    public struct Flag: Equatable, Sendable {
        public var decisionID: String
        public var project: String
        public var kind: Kind
    }

    public static let maxFlags = 5

    public static func kind(of item: InboxItem) -> Kind {
        if item.id.contains(":approval:") { return item.id.hasSuffix(":risky") ? .careful : .needs }
        return item.id.contains(":error:") ? .error : .done
    }

    /// `waiting`: the app's queue (the first one is what Hush holds). Returns flags nearest Hush first, and how many
    /// more the bundle stands for (0: no bundle).
    public static func layout(waiting: [Decision]) -> (flags: [Flag], more: Int) {
        let rest = waiting.dropFirst().filter { $0.item.kind == .agent && AgentSessionTracker.sessionID(ofItem: $0.item.id) != nil }
            .sorted { $0.at > $1.at }
        let all = rest.map { Flag(decisionID: $0.id, project: $0.item.project ?? "session", kind: kind(of: $0.item)) }
        guard all.count > maxFlags else { return (all, 0) }
        return (Array(all.prefix(maxFlags - 1)), all.count - (maxFlags - 1))
    }
}
