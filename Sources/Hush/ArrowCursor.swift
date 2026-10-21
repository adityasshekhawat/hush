import AppKit
import ObjectiveC

/// Hush's panels never make it the active app, so macOS doesn't update the cursor over them: it keeps whatever the
/// app underneath last set (an I-beam, coming from a text editor or terminal). This puts the arrow back while the
/// pointer is inside the view.
@MainActor
final class ArrowCursor: NSResponder {
    private static var key: UInt8 = 0

    static func keep(in view: NSView) {
        let owner = ArrowCursor()
        view.addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited,
                                                                   .mouseMoved, .cursorUpdate], owner: owner, userInfo: nil))
        // A tracking area doesn't keep its owner alive; the view does.
        objc_setAssociatedObject(view, &key, owner, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    override func mouseEntered(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.arrow.set() }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
}
