import CoreGraphics

/// Where a card (onboarding, Ask Hush answer, command box, tip bubble) goes relative to Hush.
/// The one rule: **never cover Hush.** Above it if there's room, otherwise beside it, always on screen.
/// Pure geometry in screen coordinates (bottom-left origin, like AppKit), so it's testable.
public enum CardPlacement {
    /// Clearance between Hush and a card. Generous because Hush hops, pops half out of the edge and grows a sprout,
    /// and the reported outline can lag a frame behind a pose change.
    public static let gap: CGFloat = 14
    /// Extra room above Hush's head for hops (the tallest hop is ~14 pt).
    public static let headroom: CGFloat = 16
    /// Cards stay this far inside the visible screen frame.
    static let margin: CGFloat = 12
    /// The command box sits this far above an answer card it follows up on.
    public static let stackGap: CGFloat = 8

    /// - Parameters:
    ///   - size: the card's size.
    ///   - character: Hush's drawn outline on screen.
    ///   - screen: the usable screen area (visible frame).
    public static func frame(size: CGSize, avoiding character: CGRect, in screen: CGRect) -> CGRect {
        let keepOut = character.insetBy(dx: -gap, dy: -gap)
            .union(CGRect(x: character.minX, y: character.maxY, width: character.width, height: headroom + gap))

        // 1. Above, centred on Hush, nudged sideways to stay on screen.
        let aboveY = keepOut.maxY
        if aboveY + size.height <= screen.maxY - margin {
            let x = clamp(character.midX - size.width / 2, screen.minX + margin, screen.maxX - size.width - margin)
            return CGRect(x: x, y: aboveY, width: size.width, height: size.height)
        }
        // 2. Beside: whichever side has more room, bottom-aligned with Hush, pushed up to stay on screen.
        let leftRoom = keepOut.minX - screen.minX
        let rightRoom = screen.maxX - keepOut.maxX
        let y = clamp(character.minY, screen.minY + margin, screen.maxY - size.height - margin)
        if leftRoom >= size.width + margin || leftRoom >= rightRoom {
            let x = max(screen.minX + margin, keepOut.minX - size.width)
            return CGRect(x: x, y: y, width: size.width, height: size.height)
        }
        let x = min(screen.maxX - size.width - margin, keepOut.maxX)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Directly above another card (follow-up mode), centred on it; beside it if there's no room above.
    public static func frame(size: CGSize, stackedAbove card: CGRect, in screen: CGRect) -> CGRect {
        let x = clamp(card.midX - size.width / 2, screen.minX + margin, screen.maxX - size.width - margin)
        if card.maxY + stackGap + size.height <= screen.maxY - margin {
            return CGRect(x: x, y: card.maxY + stackGap, width: size.width, height: size.height)
        }
        return frame(size: size, avoiding: card, in: screen)
    }

    static func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), max(lo, hi)) }
}
