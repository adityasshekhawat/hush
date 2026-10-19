import AppKit
import HushCore

/// "Line Peek" menu bar glyph (design round 2): a 1.5 pt outline at SF Symbols weight while idle,
/// solid while Hush is holding something, the way system icons switch to their filled versions.
/// Geometry is the designer's 18×18 SVG, y-down. The edge line sits at y=16.25 (design: 16) so the
/// 1.5 pt stroke lands on whole pixels at 2×.
enum MenuBarIcon {
    enum Variant { case outline, filled }

    /// The designer's PNG template for a state (@1x/@2x/@3x), or nil if the files are missing.
    static func template(_ glyph: MenuBarBadge.Glyph) -> NSImage? {
        let dir = Assets.root.appendingPathComponent("brand/menu-bar")
        let image = NSImage(size: NSSize(width: 18, height: 18))
        for suffix in ["", "@2x", "@3x"] {
            let url = dir.appendingPathComponent("HushStatus-\(glyph.rawValue)Template\(suffix).png")
            guard let rep = NSImageRep(contentsOf: url) else { continue }
            rep.size = NSSize(width: 18, height: 18)
            image.addRepresentation(rep)
        }
        guard !image.representations.isEmpty else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = "Hush"
        return image
    }

    static func image(_ variant: Variant) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let (fill, stroke) = paths(variant)
            NSColor.black.set()
            fill.fill()
            stroke.stroke()
            return true
        }
        // Template: macOS tints it for light/dark bars and inverts it when the menu is open.
        image.isTemplate = true
        image.accessibilityDescription = "Hush"
        return image
    }

    private static let edgeY: CGFloat = 16.25

    private static func paths(_ variant: Variant) -> (fill: NSBezierPath, stroke: NSBezierPath) {
        let fill = NSBezierPath()
        // Even-odd so the filled head's eyes are cut out of it.
        fill.windingRule = .evenOdd
        let stroke = NSBezierPath()
        stroke.lineWidth = 1.5
        stroke.lineCapStyle = .round
        stroke.lineJoinStyle = .round

        stroke.move(to: p(1.75, edgeY))
        stroke.line(to: p(16.25, edgeY))

        switch variant {
        case .outline:
            stroke.move(to: p(3.25, edgeY))
            stroke.line(to: p(3.25, 10.6))
            stroke.curve(to: p(9, 5.25), controlPoint1: p(3.25, 7.3), controlPoint2: p(5.8, 5.25))
            stroke.curve(to: p(14.75, 10.6), controlPoint1: p(12.2, 5.25), controlPoint2: p(14.75, 7.3))
            stroke.line(to: p(14.75, edgeY))
            stroke.move(to: p(9, 5.25))
            stroke.curve(to: p(9.7, 2.8), controlPoint1: p(9, 4.3), controlPoint2: p(9.2, 3.5))

            leaf(fill, dy: 0)
            fill.appendOval(in: oval(6.8, 10.6, 1.05, 1.35))
            fill.appendOval(in: oval(11.2, 10.6, 1.05, 1.35))
        case .filled:
            stroke.move(to: p(9, 4.6))
            stroke.curve(to: p(9.7, 2.6), controlPoint1: p(9, 3.8), controlPoint2: p(9.2, 3.2))

            fill.move(to: p(2.5, edgeY))
            fill.line(to: p(2.5, 10.6))
            fill.curve(to: p(9, 4.5), controlPoint1: p(2.5, 6.9), controlPoint2: p(5.4, 4.5))
            fill.curve(to: p(15.5, 10.6), controlPoint1: p(12.6, 4.5), controlPoint2: p(15.5, 6.9))
            fill.line(to: p(15.5, edgeY))
            fill.close()
            fill.appendOval(in: oval(7.2, 10.1, 1.2, 1.5))
            fill.appendOval(in: oval(11.6, 10.1, 1.2, 1.5))
            leaf(fill, dy: -0.2)
        }
        return (fill, stroke)
    }

    /// The sprout leaf; the filled pose sits 0.2 pt higher with the taller head.
    private static func leaf(_ path: NSBezierPath, dy: CGFloat) {
        path.move(to: p(9.4, 3.1 + dy))
        path.curve(to: p(5.8, 2.1 + dy), controlPoint1: p(8.2, 3.8 + dy), controlPoint2: p(6.5, 3.5 + dy))
        path.curve(to: p(9.4, 3.1 + dy), controlPoint1: p(6.8, 1.2 + dy), controlPoint2: p(8.7, 1.6 + dy))
        path.close()
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

    private static func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> NSRect {
        NSRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)
    }
}
