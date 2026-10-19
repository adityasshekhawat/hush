import AppKit
import CoreAudio
import HushCore
import IOKit.ps
import os

private let log = Logger(subsystem: "dev.hush.Hush", category: "play")

/// Cheap, permission-free signals for Hush's playful side. Nothing here reads content:
/// - copy: the pasteboard's change *counter*, never what was copied
/// - paste: only while Hush is holding a copy (`watchForPaste`): ⌘+V key state if macOS shares it, else
///   "a ⌘ shortcut that didn't change the clipboard". No event tap, no key content, nothing recorded (ADR-008)
/// - screenshot: a Spotlight query for new screen captures, plus the screenshot UI's windows appearing
///   (window owner names are visible without Screen Recording permission)
/// - charger / low battery: IOKit power source state
/// - music: the default output device is running (not what's playing)
/// - window drags: window *bounds* moving near Hush
@MainActor
public final class PlaySensors {
    public enum Event: Equatable {
        case copied
        case pasted
        case screenshot
        case chargerPlugged
        case batteryLow(Bool)
        case audioPlaying(Bool)
        /// A window is being dragged near Hush. `dx` > 0 means it's moving right.
        case windowPassing(dx: CGFloat)
    }

    public var onEvent: ((Event) -> Void)?
    /// Pasteboard change count of a copy Hush made itself (e.g. the card's Copy button): not "you copied".
    nonisolated(unsafe) public static var ownCopyChangeCount: Int?
    /// Hush's frame in CoreGraphics global coordinates (top-left origin). Set by the app.
    public var watchRect: CGRect = .null
    /// Our own process, so our panels don't count as "windows passing".
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    private var timer: Timer?
    private var pasteTimer: Timer?
    private var pasteKeyWasDown = false
    private var lastShortcutKeyDown: TimeInterval = 0
    private var pendingShortcut: (at: TimeInterval, changeCount: Int)?
    private var cmdHeldSince: TimeInterval?
    private var cmdLastSeen: TimeInterval = 0
    private var lastCopyAt: TimeInterval = 0
    /// When another app last came forward (⌘Tab and clicks): a ⌘ shortcut followed by this wasn't a paste.
    private var lastAppSwitch: TimeInterval?
    private var appObserver: Any?

    /// Turn on while the cheeks are full; off otherwise, so key state is only ever checked when it matters.
    public var watchForPaste = false {
        didSet {
            guard watchForPaste != oldValue else { return }
            pasteTimer?.invalidate()
            pasteTimer = nil
            pasteKeyWasDown = false
            pendingShortcut = nil
            guard watchForPaste else { return }
            // Ignore the ⌘C that started this.
            lastShortcutKeyDown = Self.lastKeyDownUptime()
            note("paste: watching (cheeks full)")
            schedulePasteTimer(fast: false)
        }
    }
    private var ticks = 0
    private var changeCount = NSPasteboard.general.changeCount
    private var windowOrigins: [Int: CGPoint] = [:]
    private var screenshotUIVisible = false
    private var lastScreenshot = Date.distantPast
    private var lastPassing = Date.distantPast
    private var audioRunningSince: Date?
    private var audioStoppedSince: Date?
    private var audioPlaying = false
    private var onAC: Bool?
    private var batteryLow = false
    private let shotQuery = NSMetadataQuery()

    public init() {}

    public func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 0.05
        startScreenshotQuery()
        checkPower()
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lastAppSwitch = ProcessInfo.processInfo.systemUptime }
        }
    }

    public func stop() {
        timer?.invalidate()
        shotQuery.stop()
    }

    private func tick() {
        ticks += 1
        if ticks % 2 == 0 { checkPasteboard() }
        // The full window list is the expensive call. Windows only get dragged with a button held, so scan at
        // 4 Hz then and once a second otherwise (enough to catch the screenshot UI appearing).
        let buttonDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        if buttonDown || ticks % 4 == 0 { checkWindows() }
        if ticks % 4 == 0 { checkAudio() }
        if ticks % 20 == 0 { checkPower() }
    }

    // MARK: copy

    private func checkPasteboard() {
        let c = NSPasteboard.general.changeCount
        guard c != changeCount else { return }
        changeCount = c
        if c == Self.ownCopyChangeCount { return }
        lastCopyAt = ProcessInfo.processInfo.systemUptime
        note("copy: clipboard changed")
        onEvent?(.copied)
    }

    // MARK: paste

    /// kVK_ANSI_V. Physical key, so non-QWERTY layouts won't match; the cheeks still empty on a timer.
    private static let vKey: CGKeyCode = 0x09

    private static func lastKeyDownUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
            - CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    private func note(_ m: String) {
        log.notice("\(m, privacy: .public)")
        DiagnosticsLog.write(m)
    }

    /// Cheeks can stay full for hours, so: 10 Hz until ⌘ goes down, 30 Hz while it's held.
    private var pasteFast = false
    private func schedulePasteTimer(fast: Bool) {
        guard pasteTimer == nil || fast != pasteFast else { return }
        pasteFast = fast
        pasteTimer?.invalidate()
        pasteTimer = Timer.scheduledTimer(withTimeInterval: fast ? 1.0 / 30 : 1.0 / 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteKeys() }
        }
        pasteTimer?.tolerance = fast ? 0.005 : 0.02
    }

    private func checkPasteKeys() {
        let now = ProcessInfo.processInfo.systemUptime
        let cmd = CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand)
        if watchForPaste { schedulePasteTimer(fast: cmd || pendingShortcut != nil) }
        // When ⌘ went down and when it was last seen held, so a quick ⌘V released between polls still counts.
        if cmd {
            if cmdHeldSince == nil { cmdHeldSince = now }
            cmdLastSeen = now
        } else {
            cmdHeldSince = nil
        }

        // 1. Exact: ⌘ and the V key down together. macOS may hide letter keys from apps without
        //    Input Monitoring, in which case this never fires and (2) takes over.
        let vDown = cmd && CGEventSource.keyState(.combinedSessionState, key: Self.vKey)
        if vDown && !pasteKeyWasDown {
            note("paste: ⌘V key state")
            pendingShortcut = nil
            lastShortcutKeyDown = Self.lastKeyDownUptime()
            onEvent?(.pasted)
        }
        pasteKeyWasDown = vDown

        // 2. Fallback: a new key-down that happened while ⌘ was held (or within 60 ms of letting go),
        //    and the clipboard didn't change within 0.3 s. If it changed, that was ⌘C/⌘X: a copy (gulp).
        let keyDownAt = Self.lastKeyDownUptime()
        let cmdWindowStart = (cmdHeldSince ?? cmdLastSeen) - 0.03
        // +0.12 s of slack: at 10 Hz the last "⌘ held" sample can be up to 100 ms before you let go.
        let cmdWindowEnd = cmd ? now : cmdLastSeen + 0.12
        // Ignore anything within 0.6 s of a copy: that's the ⌘C itself (the log showed one counted as a paste).
        if keyDownAt - lastShortcutKeyDown > 0.05, keyDownAt >= cmdWindowStart, keyDownAt <= cmdWindowEnd,
           now - keyDownAt < 0.5, now - lastCopyAt > 0.6 {
            lastShortcutKeyDown = keyDownAt
            pendingShortcut = (keyDownAt, changeCount)
            note("paste: ⌘ shortcut seen (⌘ held \(String(format: "%.2f", cmdWindowEnd - cmdWindowStart))s, key \(String(format: "%.0f", (now - keyDownAt) * 1000))ms ago)")
        }
        // 3. Decide once it's clear (PasteGuess, tested): a copy, ⌘Tab to another app, or a paste.
        if let p = pendingShortcut {
            let verdict = PasteGuess.verdict(
                shortcutAt: p.at, now: now, commandDown: cmd, commandUpAt: cmd ? nil : cmdLastSeen,
                clipboardChanged: NSPasteboard.general.changeCount != p.changeCount, lastAppSwitch: lastAppSwitch)
            switch verdict {
            case .wait: break
            case .paste:
                pendingShortcut = nil
                note("paste: no clipboard change, no app switch → paste")
                onEvent?(.pasted)
            case .copy:
                pendingShortcut = nil
                note("paste: clipboard changed → copy, not paste")
            case .appSwitch:
                pendingShortcut = nil
                note("paste: another app came forward (⌘Tab) → not a paste")
            case .unclear:
                pendingShortcut = nil
                note("paste: ⌘ held too long → not counted")
            }
        }
    }

    // MARK: windows (drags near Hush, screenshot UI)

    private func checkWindows() {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return }
        var origins: [Int: CGPoint] = [:]
        var shotUI = false
        let near = watchRect.isNull ? CGRect.null : watchRect.insetBy(dx: -70, dy: -70)
        for w in list {
            if (w[kCGWindowOwnerName as String] as? String) == "screencaptureui" { shotUI = true }
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? pid_t) != ownPID,
                  let id = w[kCGWindowNumber as String] as? Int,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let width = b["Width"], let height = b["Height"] else { continue }
            let origin = CGPoint(x: x, y: y)
            origins[id] = origin
            if let prev = windowOrigins[id], hypot(origin.x - prev.x, origin.y - prev.y) > 3,
               !near.isNull, CGRect(x: x, y: y, width: width, height: height).intersects(near),
               Date().timeIntervalSince(lastPassing) > 1.2 {
                lastPassing = Date()
                onEvent?(.windowPassing(dx: origin.x - prev.x))
            }
        }
        windowOrigins = origins
        if shotUI && !screenshotUIVisible { screenshotTaken() }
        screenshotUIVisible = shotUI
    }

    // MARK: screenshots

    private func startScreenshotQuery() {
        shotQuery.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1 AND kMDItemContentCreationDate >= %@",
                                          Date() as NSDate)
        shotQuery.searchScopes = [NSMetadataQueryUserHomeScope]
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: shotQuery, queue: .main) { [weak self] n in
            let added = (n.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [Any])?.count ?? 0
            guard added > 0 else { return }
            MainActor.assumeIsolated { self?.screenshotTaken() }
        }
        shotQuery.start()
    }

    private func screenshotTaken() {
        // Both signals can fire for one screenshot.
        guard Date().timeIntervalSince(lastScreenshot) > 3 else { return }
        lastScreenshot = Date()
        onEvent?(.screenshot)
    }

    // MARK: music

    private func checkAudio() {
        let running = Self.outputRunning()
        let now = Date()
        if running {
            audioStoppedSince = nil
            if audioRunningSince == nil { audioRunningSince = now }
            // Needs a few seconds of sound, so a notification ping doesn't start a dance.
            if !audioPlaying, now.timeIntervalSince(audioRunningSince!) >= 3 {
                audioPlaying = true
                onEvent?(.audioPlaying(true))
            }
        } else {
            audioRunningSince = nil
            if audioStoppedSince == nil { audioStoppedSince = now }
            if audioPlaying, now.timeIntervalSince(audioStoppedSince!) >= 3 {
                audioPlaying = false
                onEvent?(.audioPlaying(false))
            }
        }
    }

    static func outputRunning() -> Bool {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    // MARK: power

    private func checkPower() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let desc = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any]
        else { return }  // desktop Mac: no battery, no antics
        let ac = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let low = !ac && current * 100 / Swift.max(1, max) <= 20
        if let was = onAC, !was, ac { onEvent?(.chargerPlugged) }
        onAC = ac
        if low != batteryLow {
            batteryLow = low
            onEvent?(.batteryLow(low))
        }
    }
}
