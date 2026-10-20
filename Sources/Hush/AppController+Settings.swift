import AppKit
import HushCore
import HushMac
import SwiftUI

/// User settings: look, home spot, full-screen behaviour, perch, moods, persistence.
extension AppController {
    func setLook(_ change: (inout CharacterLook) -> Void) {
        change(&look)
        renderer.apply(look)
        flagRail?.setAccent(Assets.accent(of: look.palette))
        Self.save(look, key: "look")
    }

    /// ADR-006: off by default. On = the old PRD behaviour (vanish in full-screen apps).
    var hidesInFullScreen: Bool {
        get { defaults.bool(forKey: "hideInFullScreen") }
        set { defaults.set(newValue, forKey: "hideInFullScreen"); applyFullScreenPreference() }
    }

    func applyFullScreenPreference() {
        panel.setFollowsIntoFullScreen(!hidesInFullScreen)
        focus.detectsFullScreen = hidesInFullScreen
    }

    func setHome(_ x: CGFloat) {
        homeX = x
        defaults.set(x, forKey: "homeX")
        // Waddle there along the edge rather than teleporting.
        if wanderer.isAway { wanderer.cancel() }
        wanderer.walkHome()
    }

    /// Nothing to show, not busy, not held: OK to perch on a window.
    var canWander: Bool {
        active == nil && !focus.state.isBusy && !focus.state.hidesCharacter && !isLifted && !panelHidden
            && previewOverride == nil && !gestureView.isTracking && (currentState == .peek || currentState == .doze)
    }

    /// Hush's windows (character, cards, box, bubbles) are left out of screen shares, recordings and screenshots.
    var hiddenFromCapture: Bool {
        get { defaults.object(forKey: "hiddenFromCapture") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hiddenFromCapture"); applyCapturePrivacy() }
    }

    func applyCapturePrivacy(_ window: NSWindow? = nil) {
        let type: NSWindow.SharingType = hiddenFromCapture ? .none : .readOnly
        for w in window.map({ [$0] }) ?? NSApp.windows where w.sharingType != type { w.sharingType = type }
    }

    /// Cards and bubbles are created on demand: cover each one as it first appears.
    func watchNewWindowsForCapturePrivacy() {
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { [weak self] n in
            guard let w = n.object as? NSWindow else { return }
            MainActor.assumeIsolated { self?.applyCapturePrivacy(w) }
        }
    }

    var perchEnabled: Bool {
        get { defaults.object(forKey: "perchEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "perchEnabled"); wanderer?.perchEnabled = newValue; if !newValue { wanderer?.leavePerch() } }
    }

    /// Opt-in: an unopened mail makes Hush tap its foot (10 min), cross its arms (20), stomp once and huff (40).
    var moodsEnabled: Bool {
        get { defaults.bool(forKey: "moods") }
        set { defaults.set(newValue, forKey: "moods"); if !newValue { resetMood() }; armIgnoreTimer() }
    }

    func setSettings(_ change: (inout HushSettings) -> Void) {
        change(&settings)
        Self.save(settings, key: "settings")
        let s = settings
        Task { await engine.update(settings: s) }
        planReminders()
    }

    static func load<T: Decodable>(_: T.Type, key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    static func save<T: Encodable>(_ v: T, key: String) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: key) }
    }

    // MARK: developer simulation (until the MailKit extension exists)
}
