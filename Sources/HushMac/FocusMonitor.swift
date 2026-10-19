import AppKit
import CoreAudio
import CoreGraphics
import HushCore

/// FR-7: works out whether the user is in a call, full-screen, or typing. Needs no permissions:
/// - in a call: the default microphone is running (catches Zoom, Meet in a browser, FaceTime, Slack huddles)
/// - full-screen: a normal-layer window of the frontmost app covers a whole screen (window bounds are readable
///   without Screen Recording permission; only titles are restricted)
/// - typing: keys going down for a couple of seconds, with an 8 s release (event *timing* only, never content)
///
/// Screen sharing isn't detected yet; it nearly always coincides with a call, which is.
@MainActor
public final class FocusMonitor {
    public private(set) var state = UserFocus.idle
    public var onChange: ((UserFocus) -> Void)?
    /// Typing has to last this long before it counts (one stray key shouldn't send Hush ducking).
    public var typingStreak: TimeInterval = 2
    /// Once typing, this long without a key press ends it (so it doesn't bob up between sentences).
    public var typingRelease: TimeInterval = 8

    /// When false, full-screen apps don't count as busy (ADR-006: default for people who full-screen everything).
    public var detectsFullScreen = false {
        didSet { refresh() }
    }

    /// No input of any kind for this long → away (Hush may doze).
    public var awayAfter: TimeInterval = 5 * 60

    /// You paused Hush until then (ADR-022). Cleared here when it passes, then `onPauseEnded` fires.
    public var pausedUntil: Date? {
        didSet { refresh() }
    }
    public var onPauseEnded: (() -> Void)?
    /// Screen locked or displays asleep (system notifications, no polling).
    private var screenLocked = false
    private var displaysAsleep = false
    private var lockObservers: [(NotificationCenter, NSObjectProtocol)] = []

    private var streakStart: Date?

    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?

    public init() {}

    public func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let dnc = DistributedNotificationCenter.default()
        let ws = NSWorkspace.shared.notificationCenter
        let watch: [(NotificationCenter, String, @MainActor (FocusMonitor) -> Void)] = [
            (dnc, "com.apple.screenIsLocked", { $0.screenLocked = true }),
            (dnc, "com.apple.screenIsUnlocked", { $0.screenLocked = false }),
            (ws, NSWorkspace.screensDidSleepNotification.rawValue, { $0.displaysAsleep = true }),
            (ws, NSWorkspace.screensDidWakeNotification.rawValue, { $0.displaysAsleep = false }),
        ]
        for (center, name, apply) in watch {
            let o = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    apply(self)
                    self.refresh()
                }
            }
            lockObservers.append((center, o))
        }
        refresh()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        for (center, o) in lockObservers { center.removeObserver(o) }
        lockObservers = []
    }

    public func refresh() {
        if let until = pausedUntil, until <= Date() {
            pausedUntil = nil   // didSet refreshes
            onPauseEnded?()
            return
        }
        let next = UserFocus(
            inCall: Self.microphoneInUse(),
            screenSharing: false,
            fullScreen: detectsFullScreen && Self.frontmostIsFullScreen(),
            typing: typingNow(),
            away: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: Self.anyInput) >= awayAfter,
            paused: pausedUntil != nil,
            locked: screenLocked || displaysAsleep)
        if next != state {
            state = next
            onChange?(next)
        }
    }

    private func typingNow() -> Bool {
        let sinceKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        if sinceKey < 2.5 {
            let start = streakStart ?? Date().addingTimeInterval(-sinceKey)
            streakStart = start
            return state.typing || Date().timeIntervalSince(start) >= typingStreak
        }
        if state.typing && sinceKey < typingRelease { return true }
        streakStart = nil
        return false
    }

    // MARK: probes

    /// kCGAnyInputEventType: keyboard, mouse, trackpad, anything.
    static let anyInput = CGEventType(rawValue: ~0)!

    static func microphoneInUse() -> Bool {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    static func frontmostIsFullScreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let screens = NSScreen.screens.map { $0.frame.size }
        for w in list {
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == front.processIdentifier,
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = b["Width"], let height = b["Height"] else { continue }
            if screens.contains(where: { abs($0.width - width) < 1 && abs($0.height - height) < 1 }) { return true }
        }
        return false
    }
}
