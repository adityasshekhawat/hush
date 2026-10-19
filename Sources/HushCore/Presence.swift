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
