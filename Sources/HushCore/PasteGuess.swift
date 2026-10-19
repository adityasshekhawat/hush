import Foundation

/// Was that ⌘ shortcut a paste? (ADR-008, ADR-020.) macOS has no paste event for apps without Input Monitoring, so
/// PlaySensors sees only "⌘ plus some key went down". This decides, from signals that need no permission:
/// - the clipboard changed → it was a copy (⌘C/⌘X), not a paste;
/// - another app came forward → it was ⌘Tab (which switches on release), not a paste;
/// - otherwise, once ⌘ has been let go for a moment → a paste.
/// Pure and time-injected (system uptime seconds), so the cases are tested.
public enum PasteGuess {
    public enum Verdict: Equatable, Sendable {
        case paste
        case copy
        case appSwitch
        /// ⌘ held for ages (picking in the ⌘Tab switcher, or something else): don't guess.
        case unclear
        /// Not decided yet; ask again on the next poll.
        case wait
    }

    /// ⌘Tab activates the app a beat after ⌘ comes up; wait this long after release before calling it a paste.
    public static let settle: TimeInterval = 0.35
    /// The earliest a paste can be called after the shortcut (the clipboard may still be changing from a ⌘C).
    public static let minimum: TimeInterval = 0.3
    /// ⌘ still down this long after the shortcut: not a quick ⌘V.
    public static let giveUp: TimeInterval = 4

    public static func verdict(shortcutAt: TimeInterval, now: TimeInterval, commandDown: Bool, commandUpAt: TimeInterval?,
                               clipboardChanged: Bool, lastAppSwitch: TimeInterval?) -> Verdict {
        if clipboardChanged { return .copy }
        if let s = lastAppSwitch, s >= shortcutAt - 0.05 { return .appSwitch }
        if commandDown { return now - shortcutAt > giveUp ? .unclear : .wait }
        let releasedAt = max(commandUpAt ?? shortcutAt, shortcutAt)
        return now - releasedAt >= settle && now - shortcutAt >= minimum ? .paste : .wait
    }
}
