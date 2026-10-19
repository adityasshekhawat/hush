import AppKit
import HushCore
import HushMac
import SwiftUI

/// Adaptive pointer polling (5/20 Hz), hover hit-testing and eye-tracking updates (ADR-011).
extension AppController {
    /// Pointer polling: 5 Hz while the cursor is still, 20 Hz while it moves, you're holding Hush, or the window it's
    /// perched on is being dragged. Most of the time the cursor isn't moving, so this is most of the app's idle cost.
    func schedulePointerTimer(fast: Bool) {
        guard fast != pointerFast || pointerTimer == nil else { return }
        pointerFast = fast
        pointerTimer?.invalidate()
        let t = Timer(timeInterval: fast ? 1.0 / 20 : 1.0 / 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackPointer() }
        }
        t.tolerance = fast ? 0.004 : 0.05
        RunLoop.main.add(t, forMode: .common)
        pointerTimer = t
    }

    func trackPointer() {
        let m = NSEvent.mouseLocation
        if m != lastMouse { lastMouse = m; lastMouseMove = Date() }
        // Perched: a window only moves while it's being dragged (button held), so follow fast only then.
        let draggingWindow = wanderer?.place == .perched && CGEventSource.buttonState(.combinedSessionState, button: .left)
        let active = Date().timeIntervalSince(lastMouseMove) < 1 || gestureView.isTracking || draggingWindow
        schedulePointerTimer(fast: active)
        guard panel.isVisible else { return }
        wanderer?.follow()
        let f = panel.frame
        let local = CGPoint(x: m.x - f.minX, y: f.maxY - m.y)
        // Only bother the renderer when the cursor is within reach (designer spec: eyes track within ~200 px).
        // Far away, send one last update so the eyes settle, then stay quiet while you work elsewhere.
        let near = hypot(m.x - f.midX, m.y - f.midY) < Self.pointerReach
        if near || pointerWasNear { renderer.pointer(at: local) }
        pointerWasNear = near
        if pointerFast { antics.pointer(x: m.x) }
        let over = characterBounds.contains(local)
        // Keep receiving events for the whole gesture, even if the pointer outruns the character.
        panel.ignoresMouseEvents = !(over || gestureView.isTracking)
        if over != hovered {
            hovered = over
            if over { onboarding?.observed("hover") }
            renderer.react(.hover(over))
        }
    }
}
