import Foundation

/// What the menu bar item shows: outline while idle, filled while something waits for you,
/// and a count beside it only if you asked for one (off by default; Hush is meant to be quiet).
public struct MenuBarBadge: Equatable, Sendable {
    /// The designer's template glyphs (assets/brand/menu-bar): one per state. Never shows the held-back number.
    public enum Glyph: String, Sendable, CaseIterable {
        case idle, mail, meeting, focus, sleep, paused
    }

    public let holding: Bool
    public let glyph: Glyph
    /// Text beside the glyph, or nil for the glyph alone.
    public let count: String?

    /// - Parameters:
    ///   - meetingWaiting: one of the waiting items is a meeting.
    ///   - focused: you're on a call, sharing, or in full screen (Hush is hidden).
    ///   - asleep: quiet hours, or Hush has been tucked in for the night.
    ///   - paused: you paused Hush; that's what the bar shows until it ends (v1 art).
    public init(waiting: Int, showCount: Bool, meetingWaiting: Bool = false, focused: Bool = false, asleep: Bool = false,
                paused: Bool = false) {
        holding = waiting > 0
        count = holding && showCount ? (waiting > 9 ? "9+" : "\(waiting)") : nil
        glyph = paused ? .paused : meetingWaiting ? .meeting : holding ? .mail : focused ? .focus : asleep ? .sleep : .idle
    }
}
