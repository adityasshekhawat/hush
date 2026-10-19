import AppKit

/// The transparent, always-on-top window Hush lives in (PRD § Surfaces 1).
/// - Never becomes key or activates the app, so it never steals focus.
/// - Joins every Space, including full-screen apps, unless "Hide in full-screen apps" is on (ADR-006).
/// - Click-through outside the character: the controller toggles `ignoresMouseEvents` from the drawn bounds.
final class OverlayPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        setFollowsIntoFullScreen(true)
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
    }

    func setFollowsIntoFullScreen(_ on: Bool) {
        collectionBehavior = on
            ? [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            : [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Sits over the renderer and turns mouse input into Hush gestures.
final class GestureView: NSView {
    enum Gesture {
        case pressBegan
        /// Held still past `patDelay`: a pat.
        case patBegan
        case click
        /// A quick flick, or a right-click: "go away" (FR-11).
        case shoo
        case dragBegan
        /// The window should move by this much; `vx` is horizontal velocity in points/second.
        case drag(dx: CGFloat, dy: CGFloat, vx: CGFloat)
        case dragEnded
        /// Button released after a press, pat or drag. Sent before click / shoo / dragEnded.
        case released
    }

    var onGesture: ((Gesture) -> Void)?
    private(set) var isTracking = false

    private var downAt: (point: NSPoint, time: TimeInterval)?
    private var last: (point: NSPoint, time: TimeInterval) = (.zero, 0)
    private var vx: CGFloat = 0
    private var dragging = false
    private var patting = false
    private var patTimer: Timer?

    static let flickDistance: CGFloat = 50
    static let flickTime: TimeInterval = 0.35
    static let patDelay: TimeInterval = 0.45

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with e: NSEvent) {
        let p = NSEvent.mouseLocation
        downAt = (p, e.timestamp)
        last = (p, e.timestamp)
        vx = 0
        dragging = false
        patting = false
        isTracking = true
        onGesture?(.pressBegan)
        patTimer = Timer.scheduledTimer(withTimeInterval: Self.patDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isTracking, !self.dragging else { return }
                self.patting = true
                self.onGesture?(.patBegan)
            }
        }
    }

    override func mouseDragged(with e: NSEvent) {
        guard let downAt else { return }
        let p = NSEvent.mouseLocation
        if !dragging, !patting, hypot(p.x - downAt.point.x, p.y - downAt.point.y) > 4 {
            dragging = true
            patTimer?.invalidate()
            onGesture?(.dragBegan)
        }
        if dragging {
            let dt = max(0.001, e.timestamp - last.time)
            vx = vx * 0.6 + ((p.x - last.point.x) / dt) * 0.4   // smoothed
            onGesture?(.drag(dx: p.x - last.point.x, dy: p.y - last.point.y, vx: vx))
        }
        last = (p, e.timestamp)
    }

    override func mouseUp(with e: NSEvent) {
        patTimer?.invalidate()
        guard let downAt else { return }
        let outcome: Gesture?
        if patting {
            outcome = nil
        } else if !dragging {
            outcome = .click
        } else {
            let p = NSEvent.mouseLocation
            let fast = e.timestamp - downAt.time < Self.flickTime
            let far = hypot(p.x - downAt.point.x, p.y - downAt.point.y) > Self.flickDistance
            outcome = fast && far ? .shoo : .dragEnded
        }
        self.downAt = nil
        dragging = false
        patting = false
        isTracking = false
        // Release first so the press squash ends before the click/drop reaction starts.
        onGesture?(.released)
        if let outcome { onGesture?(outcome) }
    }

    override func rightMouseDown(with e: NSEvent) { onGesture?(.shoo) }
}
