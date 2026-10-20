import AppKit
import HushCore
import HushMac

/// Moves Hush around the screen: window perching (PRD § Delight, v1) and the edge walk between spots.
///
/// Perch: after a stretch with no input, Hush hops onto the top edge of the focused window, swings its legs, follows
/// the window if it moves, and nods off after five minutes. Any key, click or scroll ends it (a perched character
/// could otherwise sit on a tab strip you're about to click); mouse movement alone doesn't, so its eyes can follow you.
/// It skips full-screen windows and windows touching the top of the screen (it would sit under the menu bar).
@MainActor
final class Wanderer {
    struct Host {
        var panel: OverlayPanel
        var react: (Reaction) -> Void
        var homeFrame: () -> NSRect
        /// Art height in points (the floor line sits 34/146 of it above the panel's bottom).
        var artHeight: CGFloat
        /// Nothing to show, not busy, not being dragged: OK to wander off.
        var canWander: () -> Bool
    }

    enum Where: Equatable { case home, walking, jumping, perched, falling }

    private let host: Host
    private(set) var place: Where = .home
    var perchEnabled = true

    /// No input for this long → perch.
    static let idleBeforePerch: TimeInterval = 120
    static let perchDozeAfter: TimeInterval = 5 * 60

    private var tickTimer: Timer?
    private var walkTimer: Timer?
    private var perch: (windowID: CGWindowID, offsetX: CGFloat, lastBounds: CGRect, since: Date, inputBaseline: TimeInterval)?
    /// Put there by you (dropped on a window edge): stays through keys and clicks, only leaves with the window.
    private var pinned = false
    private var dozing = false

    init(host: Host) { self.host = host }

    var isAway: Bool { place != .home }

    func start() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: perch

    private func tick() {
        guard place == .home, perchEnabled, host.canWander(),
              Self.secondsSince(Self.anyInput) >= Self.idleBeforePerch,
              let w = Self.focusedWindow() else { return }
        hop(onto: w)
    }

    private func hop(onto w: (id: CGWindowID, bounds: CGRect)) {
        place = .jumping
        let size = host.panel.frame.size
        let target = perchFrame(for: w.bounds, offsetX: w.bounds.width * 0.72 - size.width / 2)
        perch = (w.id, target.minX - Self.screenRect(w.bounds).minX, w.bounds, Date(), Self.inputUptime())
        pinned = false
        host.react(.jump)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self, self.place == .jumping else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.host.panel.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.place == .jumping else { return }
                    self.place = .perched
                    self.dozing = false
                    self.host.react(.mode("perch", true))
                }
            })
        }
    }

    /// Called at 30 Hz from the pointer timer while perched: follow the window, doze, or leave.
    func follow() {
        guard place == .perched, let p = perch else { return }
        // Any key, click or scroll since we perched → hop down (unless you put it there yourself).
        if !pinned, Self.inputUptime() > p.inputBaseline + 0.05 { leavePerch(); return }
        guard let b = Self.bounds(of: p.windowID), !Self.isFullScreen(b) else { leavePerch(); return }
        if b != p.lastBounds {
            perch?.lastBounds = b
            host.panel.setFrame(perchFrame(for: b, offsetX: p.offsetX), display: true)
        }
        if !dozing, Date().timeIntervalSince(p.since) >= Self.perchDozeAfter {
            dozing = true
            host.react(.perchDoze(true))
        }
    }

    /// Dropped by the user: if Hush's floor line is within a few points of a window's top edge (and over it),
    /// settle onto that edge and stay. Returns false if there's no edge there.
    func perchOnDrop() -> Bool {
        let frame = host.panel.frame
        let screenH = NSScreen.screens.first?.frame.height ?? 0
        // Floor line and centre in CoreGraphics coordinates (top-left origin), as CGWindowList reports windows.
        let floorY = screenH - (frame.minY + host.artHeight * 34 / 146)
        let cx = frame.midX
        guard let w = Self.window(withTopEdgeNear: CGPoint(x: cx, y: floorY), tolerance: 28) else { return false }
        let r = Self.screenRect(w.bounds)
        let target = perchFrame(for: w.bounds, offsetX: frame.minX - r.minX)
        host.panel.setFrame(target, display: true)
        perch = (w.id, target.minX - r.minX, w.bounds, Date(), Self.inputUptime())
        pinned = true
        dozing = false
        place = .perched
        host.react(.perchLand)
        return true
    }

    /// The front-most window under `point` whose top edge is within `tolerance` of it. Stops at the first window that
    /// covers the point without its edge being close (you dropped Hush inside that window, not on an edge).
    static func window(withTopEdgeNear point: CGPoint, tolerance: CGFloat) -> (id: CGWindowID, bounds: CGRect)? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        for w in list {
            guard (w[kCGWindowLayer as String] as? Int) == 0, (w[kCGWindowOwnerPID as String] as? pid_t) != me,
                  let id = w[kCGWindowNumber as String] as? CGWindowID, let b = bounds(from: w),
                  b.width >= 200, b.height >= 120 else { continue }
            let zone = CGRect(x: b.minX + 8, y: b.minY - tolerance, width: b.width - 16, height: b.height + tolerance)
            guard zone.contains(point) else { continue }
            // Not full-screen, and not tucked under the menu bar.
            if abs(point.y - b.minY) <= tolerance, !isFullScreen(b), b.minY >= 30 { return (id, b) }
            return nil
        }
        return nil
    }

    /// Hop down where it is, land, then walk home along the edge.
    func leavePerch() {
        guard place == .perched || place == .jumping else { return }
        host.react(.mode("perch", false))
        host.react(.lift)  // dangle on the way down; .land squashes on arrival
        perch = nil
        pinned = false
        place = .falling
        let home = host.homeFrame()
        var floor = host.panel.frame
        floor.origin.y = home.minY
        if let vf = NSScreen.main?.visibleFrame { floor.origin.x = min(max(vf.minX, floor.minX), vf.maxX - floor.width) }
        let drop = max(0, host.panel.frame.minY - floor.minY)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = min(0.55, max(0.15, sqrt(drop / 2600)))
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            host.panel.animator().setFrame(floor, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.place == .falling else { return }
                self.host.react(.land(intensity: 0))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.walkHome() }
            }
        })
    }

    /// Stop wherever we are (e.g. the user grabbed Hush). The caller decides where it ends up.
    func cancel() {
        walkTimer?.invalidate()
        if place == .perched || place == .jumping { host.react(.mode("perch", false)) }
        if place == .walking { host.react(.mode("walk", false)) }
        perch = nil
        pinned = false
        place = .home
    }

    // MARK: edge walk

    /// Waddle along the bottom edge to the home spot (about 70 pt/s, never longer than ~6 s).
    func walkHome() {
        walkTimer?.invalidate()
        let target = host.homeFrame()
        let startX = host.panel.frame.minX
        let distance = abs(target.minX - startX)
        var frame = host.panel.frame
        frame.origin.y = target.minY
        host.panel.setFrame(frame, display: true)
        guard distance > 4 else { place = .home; host.panel.setFrame(target, display: true); return }
        place = .walking
        host.react(.mode("walk", true))
        let speed = max(70, distance / 6)
        let started = Date()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let travelled = min(distance, CGFloat(Date().timeIntervalSince(started)) * speed)
                var f = self.host.panel.frame
                f.origin.x = startX + (target.minX > startX ? travelled : -travelled)
                self.host.panel.setFrame(f, display: true)
                if travelled >= distance {
                    self.walkTimer?.invalidate()
                    self.host.react(.mode("walk", false))
                    self.place = .home
                }
            }
        }
    }

    // MARK: geometry

    private func perchFrame(for windowBounds: CGRect, offsetX: CGFloat) -> NSRect {
        let r = Self.screenRect(windowBounds)
        let size = host.panel.frame.size
        let x = min(max(r.minX, r.minX + offsetX), r.maxX - size.width)
        // The floor line (34/146 of the art above the panel's bottom) sits on the window's top edge.
        return NSRect(x: x, y: r.maxY - host.artHeight * 34 / 146, width: size.width, height: size.height)
    }

    /// CG (top-left origin) → AppKit screen coordinates (bottom-left origin).
    static func screenRect(_ cg: CGRect) -> NSRect {
        let h = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: cg.minX, y: h - cg.maxY, width: cg.width, height: cg.height)
    }

    static func isFullScreen(_ b: CGRect) -> Bool {
        NSScreen.screens.contains { abs($0.frame.width - b.width) < 1 && abs($0.frame.height - b.height) < 1 }
    }

    /// The video's stage window (debug hooks only): Hush's own blank window, which it may perch on.
    nonisolated(unsafe) static var stage: (() -> (id: CGWindowID, bounds: CGRect)?)?

    /// The frontmost app's front window, if it's a reasonable place to sit.
    static func focusedWindow() -> (id: CGWindowID, bounds: CGRect)? {
        if let stage = stage?() { return stage }
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        for w in list {
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == front.processIdentifier,
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let id = w[kCGWindowNumber as String] as? CGWindowID,
                  let b = bounds(from: w) else { continue }
            // Front-most normal window of that app; skip it if it's not a good perch.
            guard b.width >= 320, b.height >= 200, !isFullScreen(b), b.minY >= 40 else { return nil }
            return (id, b)
        }
        return nil
    }

    static func bounds(of id: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
              let w = list.first, (w[kCGWindowIsOnscreen as String] as? Bool) ?? false else { return nil }
        return bounds(from: w)
    }

    private static func bounds(from w: [String: Any]) -> CGRect? {
        guard let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let x = b["X"], let y = b["Y"], let width = b["Width"], let height = b["Height"] else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: input timing (no content, no permission)

    static let anyInput = CGEventType(rawValue: ~0)!

    static func secondsSince(_ type: CGEventType) -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
    }

    /// Uptime of the most recent key, click or scroll (mouse movement deliberately excluded).
    static func inputUptime() -> TimeInterval {
        let since = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel].map(secondsSince).min() ?? .infinity
        return ProcessInfo.processInfo.systemUptime - since
    }

    // Debug
    func debugPerch() {
        if let w = Self.focusedWindow() { hop(onto: w) } else { DiagnosticsLog.write("perch: no suitable window") }
    }
}
