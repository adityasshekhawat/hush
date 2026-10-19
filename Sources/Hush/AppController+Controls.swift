import AppKit
import Carbon.HIToolbox
import HushCore
import HushMac

/// Never-in-the-way controls and the energy budget (ADR-022): pause, the "hush" hotkey, energy saver, and instant
/// click-through near Hush.
extension AppController {
    // MARK: pause

    var pausedUntil: Date? { focus.pausedUntil }

    func pause(_ length: PauseLength) {
        let until = length.until(from: Date())
        defaults.set(until, forKey: "pausedUntil")
        envelope.close()
        bubble.show(PauseText.status(until: until, now: Date()) + ". ⌥⇧⌘H brings me back.", above: cardAvoidRect(), for: 4)
        focus.pausedUntil = until
        DiagnosticsLog.write("pause: until \(until)")
        onRefresh?()
    }

    func resume() {
        defaults.removeObject(forKey: "pausedUntil")
        focus.pausedUntil = nil
        DiagnosticsLog.write("pause: resumed")
        onRefresh?()
    }

    /// A pause that outlived a quit or restart.
    func restorePause() {
        focus.onPauseEnded = { [weak self] in
            self?.defaults.removeObject(forKey: "pausedUntil")
            DiagnosticsLog.write("pause: ended")
            self?.onRefresh?()
        }
        if let until = defaults.object(forKey: "pausedUntil") as? Date, until > Date() {
            focus.pausedUntil = until
        } else {
            defaults.removeObject(forKey: "pausedUntil")
        }
    }

    /// ⌥⇧⌘H, "hush": puts away what Hush is showing; with nothing showing, pauses it for an hour; paused, brings it back.
    func registerHushKey() {
        hushKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey | shiftKey | optionKey), name: "⌥⇧⌘H") { [weak self] in
            self?.hushKeyPressed()
        }
        DiagnosticsLog.write("hotkey: ⌥⇧⌘H \(hushKey == nil ? "NOT registered" : "registered")")
    }

    func hushKeyPressed() {
        if pausedUntil != nil { resume(); return }
        let showing = active != nil || envelope.isOpen || commandPanel.isOpen || pouch.isOpen
        if showing {
            envelope.close()
            if commandPanel.isOpen { toggleCommandBox() }
            if active != nil { resolveActive(.ignored) }
            DiagnosticsLog.write("hotkey: put away")
            return
        }
        pause(.hour)
    }

    // MARK: energy saver

    /// Low Power Mode or a low battery: always calm (no looping animation), slower pointer checks, no idle fidgets.
    /// Alerts still arrive.
    func watchEnergy() {
        energyObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyEnergy() }
        }
        antics.onBatteryLow = { [weak self] _ in self?.applyEnergy() }
        applyEnergy()
    }

    func applyEnergy() {
        let saver = ProcessInfo.processInfo.isLowPowerModeEnabled || antics.batteryLow || defaults.bool(forKey: "HushForceSaver")
        guard saver != energySaver else { return }
        energySaver = saver
        renderer.react(.saver(saver))
        pointerTimer?.invalidate()
        pointerTimer = nil
        schedulePointerTimer(fast: false)
        DiagnosticsLog.write("energy: saver \(saver ? "on" : "off")")
    }

    // MARK: click-through

    /// Near Hush, follow the pointer on every move (not just at the next 5 Hz poll), so the panel stops taking clicks
    /// the instant the cursor leaves Hush's body. Only installed while the cursor is within reach.
    func watchPointerClosely(_ near: Bool) {
        if near, moveMonitor == nil {
            moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
                MainActor.assumeIsolated { self?.pointerMoved() }
            }
        } else if !near, let m = moveMonitor {
            NSEvent.removeMonitor(m)
            moveMonitor = nil
        }
    }

    private func pointerMoved() {
        guard panel.isVisible, !gestureView.isTracking else { return }
        let m = NSEvent.mouseLocation
        let f = panel.frame
        let over = characterBounds.contains(CGPoint(x: m.x - f.minX, y: f.maxY - m.y))
        // Out of step with what the panel accepts: settle it now rather than at the next poll.
        if panel.ignoresMouseEvents == over { trackPointer() }
    }
}
