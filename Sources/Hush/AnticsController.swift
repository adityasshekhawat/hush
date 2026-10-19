import AppKit
import HushCore
import HushMac
import SwiftUI

/// Hush's playful side: turns PlaySensors events, pointer motion and the clock into antics, gated by AnticPolicy.
/// None of this is logged as a decision or counts toward the interrupt cap (PRD § Delight).
@MainActor
final class AnticsController {
    /// What the controller needs from the app.
    struct Host {
        var focus: () -> UserFocus
        var hasActiveAppearance: () -> Bool
        /// Hush's frame in CoreGraphics global coordinates (top-left origin).
        var characterRect: () -> CGRect
        var react: (Reaction) -> Void
        var summary: () async -> DaySummary?
        var weekSummary: () async -> DaySummary?
        var showBubble: (String) -> Void
        /// The held-back card: daily tuck-in, or the week on Fridays.
        var showHeldBack: (_ week: Bool) -> Void = { _ in }
        /// Perched or walking: the window it's riding moving isn't "a window passing by".
        var isWandering: () -> Bool = { false }
    }

    private let host: Host
    private let policy = AnticPolicy()
    private let sensors = PlaySensors()
    private let defaults = UserDefaults.standard
    private var shake = ShakeDetector()

    private var lastTouched = Date()
    private var lastPatRequest: Date?
    private var patRequestsToday = 0
    private var patCountDay = Date()
    private var asking = false
    private var askTimer: Timer?
    private var clockTimer: Timer?
    private var awaySince: Date?
    private var late = false
    /// Called on each tuck-in (the app shows the first-week tip once).
    var firstTuckIn: (() -> Void)?

    /// Cheeks stay full until a paste (or a click on Hush). No timer: "puffed till you paste".
    private(set) var cheeksFull = false
    static let patAskDuration: TimeInterval = 15

    init(host: Host) { self.host = host }

    func start() {
        sensors.onEvent = { [weak self] e in self?.handle(e) }
        sensors.start()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.clockTick() }
        }
        clockTick()
    }

    // MARK: inputs from the app

    /// Click, pat or drag on Hush.
    func touched() {
        lastTouched = Date()
        if asking { endAsk(.thanked) }
    }

    /// Every pointer sample (30 Hz), in screen points.
    func pointer(x: CGFloat) {
        sensors.watchRect = host.characterRect()
        if shake.add(x: Double(x), at: ProcessInfo.processInfo.systemUptime), may(.dizzy) {
            host.react(.woozy)
        }
    }

    func focusChanged(_ f: UserFocus) {
        if f.away {
            if awaySince == nil { awaySince = Date() }
        } else if let since = awaySince {
            awaySince = nil
            if policy.isMorning(returningAt: Date(), awaySince: since), may(.morningStretch) {
                host.react(.morning)
            }
        }
        if asking && (f.isBusy || f.hidesCharacter) { endAsk(.ignored) }
    }

    // MARK: sensors

    private func handle(_ e: PlaySensors.Event) {
        switch e {
        case .copied:
            guard may(.cheeks) else { return }
            host.react(.cheeks)
            cheeksFull = true
            sensors.watchForPaste = true
        case .pasted:
            emptyCheeks()
        case .screenshot:
            if may(.screenshot) { host.react(.flash) }
        case .chargerPlugged:
            host.react(.mode("droopy", false))
            if may(.perk) { host.react(.perk) }
        case .batteryLow(let low):
            host.react(.mode("droopy", low))
        case .audioPlaying(let on):
            host.react(.mode("groove", on))
        case .windowPassing(let dx):
            if may(.flinch), !host.isWandering() { host.react(.flinch(dx: dx)) }
        }
    }

    /// Blow the air out (on paste, or when you click it) and stop watching for ⌘V.
    func emptyCheeks() {
        guard cheeksFull else { return }
        cheeksFull = false
        sensors.watchForPaste = false
        host.react(.blow)
    }

    // MARK: clock-driven antics

    private func clockTick() {
        let now = Date()
        if !Calendar.current.isDate(patCountDay, inSameDayAs: now) {
            patCountDay = now
            patRequestsToday = 0
        }
        let isLate = policy.isLate(now)
        if isLate != late {
            late = isLate
            host.react(.mode("late", isLate))
        }

        let c = context(now)
        if !asking, policy.shouldRequestPat(c) {
            startAsk()
        } else if policy.shouldDance(c) {
            defaults.set(now, forKey: "lastFridayDance")
            host.react(.dance)
        } else if policy.shouldTuckIn(c) {
            defaults.set(now, forKey: "lastTuckIn")
            tuckIn()
        }
    }

    private func startAsk() {
        asking = true
        lastPatRequest = Date()
        patRequestsToday += 1
        host.react(.askPat(.start))
        askTimer?.invalidate()
        askTimer = Timer.scheduledTimer(withTimeInterval: Self.patAskDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.endAsk(.ignored) }
        }
    }

    private func endAsk(_ how: Reaction.PatAsk) {
        guard asking else { return }
        asking = false
        askTimer?.invalidate()
        host.react(.askPat(how))
    }

    /// The PRD's signature: "You got 4 things from me today. I held back 63."
    func tuckIn() {
        host.react(.tuckIn)
        firstTuckIn?()
        // Fridays it's the week (design guide §5.2: weekly card after 17:00; tuck-in is 18:30).
        host.showHeldBack(Calendar.current.component(.weekday, from: Date()) == 6)
    }

    // MARK: helpers

    private func may(_ a: Antic) -> Bool { policy.mayPlay(a, context(Date())) }

    private func context(_ now: Date) -> AnticContext {
        AnticContext(
            now: now, focus: host.focus(), hasActiveAppearance: host.hasActiveAppearance(),
            lastTouched: lastTouched, lastPatRequest: lastPatRequest, patRequestsToday: patRequestsToday,
            lastTuckIn: defaults.object(forKey: "lastTuckIn") as? Date,
            lastFridayDance: defaults.object(forKey: "lastFridayDance") as? Date)
    }

    // Debug hooks
    func debugAsk() { startAsk() }
    func debugEvent(_ e: PlaySensors.Event) { handle(e) }
}

/// A small, non-activating speech card above Hush. Click to dismiss; fades on its own.
@MainActor
final class Bubble {
    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(_ text: String, above anchor: NSRect, for seconds: TimeInterval = 9) {
        hide()
        // Measure the text ourselves: SwiftUI's fitting size for wrapping text comes back far too tall.
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let textRect = (text as NSString).boundingRect(
            with: NSSize(width: BubbleView.maxTextWidth, height: 1000), options: [.usesLineFragmentOrigin],
            attributes: [.font: font])
        let textSize = CGSize(width: ceil(textRect.width) + 4, height: ceil(textRect.height) + 2)
        let view = NSHostingView(rootView: BubbleView(text: text, textWidth: textSize.width))
        let size = CGSize(width: textSize.width + BubbleView.inset.width, height: textSize.height + BubbleView.inset.height)
        view.frame = NSRect(origin: .zero, size: size)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        p.contentView = view
        bubbleSize = size
        p.setFrame(CardPlacement.frame(size: size, avoiding: anchor, in: NSScreen.main?.visibleFrame ?? .zero), display: true)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; p.animator().alphaValue = 1 }
        view.onClick = { [weak self] in self?.hide() }
        panel = p
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private var bubbleSize: CGSize = .zero

    /// Hush moved or changed pose: keep clear of it.
    func relayout(avoiding character: NSRect) {
        guard let p = panel else { return }
        p.setFrame(CardPlacement.frame(size: bubbleSize, avoiding: character, in: NSScreen.main?.visibleFrame ?? .zero), display: true)
    }

    func hide() {
        hideTimer?.invalidate()
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; p.animator().alphaValue = 0 },
                                             completionHandler: { p.orderOut(nil) })
    }
}

private struct BubbleView: View {
    static let maxTextWidth: CGFloat = 230
    /// Padding plus the outer shadow margin, on both sides.
    static let inset = CGSize(width: 14 * 2 + 6 * 2, height: 10 * 2 + 6 * 2)

    let text: String
    let textWidth: CGFloat
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .multilineTextAlignment(.center)
            .frame(width: textWidth)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(6)
    }
}

private extension NSHostingView {
    /// Tap anywhere on the bubble to dismiss it.
    var onClick: (() -> Void)? {
        get { nil }
        set {
            gestureRecognizers.forEach(removeGestureRecognizer)
            guard let newValue else { return }
            addGestureRecognizer(ClickRecognizer(newValue))
        }
    }
}

private final class ClickRecognizer: NSClickGestureRecognizer {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) {
        self.handler = handler
        super.init(target: nil, action: nil)
        target = self
        action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError("unused") }
    @objc private func fire() { handler() }
}
