import AppKit
import HushCore
import HushMac
import ServiceManagement
import SwiftUI

/// Wires sources → engine → presence → renderer, and gestures back into signals.
@MainActor
final class AppController {
    let engine: DecisionEngine
    /// Apple's on-device model judges mail and writes gists when it can; otherwise the rules do (FR-14, ADR-018).
    let triage: OnDeviceTriage
    var gists: GistWriter { triage }
    let calendar = CalendarSource()
    let focus = FocusMonitor()
    let renderer: CharacterRenderer
    let panel: OverlayPanel
    let gestureView = GestureView()
    let defaults = UserDefaults.standard

    var settings: HushSettings
    var look: CharacterLook
    /// Home spot along the bottom edge: 0 = left, 1 = right.
    var homeX: CGFloat

    // Presence inputs
    var calendarMeetings: [Meeting] = []
    var demoMeetings: [Meeting] = []
    var meetings: [Meeting] { calendarMeetings + demoMeetings }
    /// Appearances waiting for a click, loudest first. `active` is the one being shown.
    var waiting: [Decision] = [] { didSet { onWaitingChange?(waiting.count) } }
    /// The menu bar glyph fills in while something waits; it dedupes, so firing on every mutation is cheap.
    var onWaitingChange: ((Int) -> Void)?
    /// After every refresh (focus and quiet hours change the menu bar glyph).
    var onRefresh: (() -> Void)?
    /// Opens the Settings window at a section (set by MenuBar).
    var openSettings: ((SettingsSection) -> Void)?
    /// Opens the menu bar panel (set by MenuBar; debug hook).
    var openPanel: (() -> Void)?
    /// Opens the Wardrobe window (D7).
    var openWardrobe: (() -> Void)?
    var gistByDecision: [String: String] = [:]
    var ambientPile = 0
    var justShooed = false
    var hurrySince: Date?
    var currentState: CharacterState?
    var currentDuck = false
    /// Developer menu: pin a pose regardless of inputs.
    var previewOverride: CharacterState? { didSet { refresh() } }
    /// Debug: preview the call/screen-share hide (dive, gone) instead of the typing duck.
    var previewAway = false

    var characterBounds: CGRect = .zero
    var pointerTimer: Timer?
    var reminderTimer: Timer?
    var ignoreTimer: Timer?
    let envelope = EnvelopePresenter()
    let rulesCard = RulesPresenter()
    let heldBack = HeldBackPresenter()
    var rare: RareFindsController!
    var panelHidden = false
    var antics: AnticsController!
    /// Hand it to Hush: rework what you copied (ADR-019).
    var pouch: PouchController!
    var wanderer: Wanderer!
    /// Your Claude Code sessions (Phase 1, docs/agent-plan.md).
    var agentSessions = AgentSessionTracker()
    let agentStatus = AgentStatusReceiver()
    let commandPanel = CommandPanel()
    let tipBubble = Bubble()
    var ask: AskController!
    var onboarding: OnboardingController!
    var digest: DigestController!
    /// Which app each Claude Code session ran in (from the hooks), for the digest's Open button.
    var sessionApps: [String: String] = [:]
    /// The app you were in when you opened the command box (context for the answer).
    var lastCommandApp: String?
    var hotKey: GlobalHotKey?
    /// ⌥⇧⌘H: put away / pause / resume (ADR-022).
    var hushKey: GlobalHotKey?
    var energyObserver: Any?
    /// Low Power Mode or low battery (ADR-022).
    var energySaver = false
    /// Global mouse-move monitor, only while the cursor is near Hush (instant click-through).
    var moveMonitor: Any?
    var agentTimer: Timer?
    /// Opt-in Moods: seconds an unopened mail has been visibly waiting (paused while you're busy).
    var moodSeconds: TimeInterval = 0
    var moodStage = 0
    var moodTimer: Timer?
    let bubble = Bubble()

    /// How long an unclicked appearance waits before it's logged as ignored and put away.
    static let gentleTimeout: TimeInterval = 5 * 60
    static let interruptTimeout: TimeInterval = 3 * 60
    /// With Moods on, an unopened mail waits long enough for the 10/20/40-minute escalation to play out.
    static let moodsTimeout: TimeInterval = 60 * 60
    static let demoVIP = "demo-vip@hush.local"

    var active: Decision? { waiting.first }

    init() throws {
        settings = Self.load(HushSettings.self, key: "settings") ?? HushSettings()
        look = Self.load(CharacterLook.self, key: "look") ?? CharacterLook()
        if !CharacterLook.bodies.contains(look.body) { look.body = "blob" }
        homeX = defaults.object(forKey: "homeX") as? CGFloat ?? 0.92

        let store = try HushStore(path: HushStore.defaultPath())
        // FR-4 / FR-14: the on-device model when Apple Intelligence is on and you haven't turned it off; rules otherwise.
        triage = OnDeviceTriage(enabled: defaults.object(forKey: "useOnDeviceModel") as? Bool ?? true)
        engine = DecisionEngine(store: store, classifier: triage, settings: settings)

        renderer = try WebCharacterRenderer(characterHeight: 104)
        let h = renderer.characterHeight * 146 / 100
        // Extra headroom above the art so the hover rise and hops never clip the topper.
        panel = OverlayPanel(size: NSSize(width: h * 160 / 146, height: h * 196 / 146))
    }

    func start() {
        let content = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
        renderer.view.frame = content.bounds
        renderer.view.autoresizingMask = [.width, .height]
        gestureView.frame = content.bounds
        gestureView.autoresizingMask = [.width, .height]
        content.addSubview(renderer.view)
        content.addSubview(gestureView)
        panel.contentView = content

        renderer.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .ready: self.refresh()
            case .bounds(let r):
                let b = r.insetBy(dx: -4, dy: -4)
                let moved = abs(b.minY - self.characterBounds.minY) > 1 || abs(b.height - self.characterBounds.height) > 1
                    || abs(b.minX - self.characterBounds.minX) > 1
                self.characterBounds = b
                // Hush changed pose (e.g. peek → stand) or popped up: every open card steps out of the way.
                if moved { self.relayoutCards() }
            }
        }
        renderer.apply(look)
        gestureView.onGesture = { [weak self] g in self?.handle(g) }

        placeAtHome()
        panel.orderFrontRegardless()

        schedulePointerTimer(fast: false)

        antics = AnticsController(host: .init(
            focus: { [weak self] in self?.focus.state ?? .idle },
            hasActiveAppearance: { [weak self] in self?.active != nil },
            characterRect: { [weak self] in self?.characterRectCG() ?? .null },
            react: { [weak self] r in self?.renderer.react(r) },
            summary: { [weak self] in try? await self?.engine.daySummary() },
            weekSummary: { [weak self] in try? await self?.engine.weekSummary() },
            showBubble: { [weak self] text in
                guard let self else { return }
                self.bubble.show(text, above: self.cardAvoidRect())
            },
            showHeldBack: { [weak self] week in self?.showHeldBack(week ? .week : .day) },
            isWandering: { [weak self] in self?.wanderer?.isAway ?? false }))
        antics.start()
        pouch = PouchController(host: .init(
            anchor: { [weak self] in self?.cardAvoidRect() ?? .zero },
            react: { [weak self] r in self?.renderer.react(r) },
            bubble: { [weak self] text in
                guard let self else { return }
                self.bubble.show(text, above: self.cardAvoidRect())
            },
            emptyCheeks: { [weak self] in self?.antics.emptyCheeks() },
            handoff: { [weak self] in self?.ask?.preferredHandoff ?? .chatgpt }))
        antics.onCheeksEmptied = { [weak self] in self?.pouch.cheeksEmptied() }
        antics.firstTuckIn = { [weak self] in
            guard let self, let text = self.onboarding?.tip(.tuckIn) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { self.tipBubble.show(text, above: self.cardAvoidRect(), for: 8) }
        }

        wanderer = Wanderer(host: .init(
            panel: panel,
            react: { [weak self] r in self?.renderer.react(r) },
            homeFrame: { [weak self] in self?.homeFrame() ?? .zero },
            artHeight: renderer.characterHeight * 146 / 100,
            canWander: { [weak self] in self?.canWander ?? false }))
        wanderer.perchEnabled = perchEnabled
        rare = RareFindsController(app: self)
        rare.start()
        watchNewWindowsForCapturePrivacy()
        applyCapturePrivacy()
        wanderer.start()
        // ⌘⇧H opens the command box (Phase 0 spike; Phase 2 sends it to the agent).
        hotKey = GlobalHotKey { [weak self] in self?.toggleCommandBox() }
        DiagnosticsLog.write("hotkey: ⌘⇧H \(hotKey == nil ? "NOT registered" : "registered")")
        registerHushKey()
        ask = AskController(host: .init(
            engine: engine,
            react: { [weak self] r in self?.renderer.react(r) },
            anchor: { [weak self] in self?.cardAvoidRect() ?? .zero },
            refresh: { [weak self] in self?.refresh() },
            submit: { [weak self] item in self?.submit(item, preset: .gentle) },
            recentSessionCwd: { [weak self] in self?.agentSessions.mostRecentCwd },
            asked: { [weak self] in self?.rare?.asked() },
            liveSessions: { [weak self] in self?.agentSessions.sessions ?? [:] },
            transcriptsAllowed: { [weak self] in self?.digest?.enabled ?? false },
            openApp: { id in
                guard let id, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { return }
                app.activate()
            },
            summarise: { [weak self] d in self?.digest?.summarise(d) },
            watched: { [weak self] in self?.agentSessions.watched ?? [] },
            setWatch: { [weak self] id, on in
                if on { self?.agentSessions.watch(id) } else { self?.agentSessions.unwatch(id) }
            }))
        commandPanel.onSubmit = { [weak self] text, lane, followUp, check in
            guard let self else { return }
            self.ask.submit(text, lane: lane, frontmostApp: self.lastCommandApp, followUp: followUp, check: check)
        }
        commandPanel.onCorrection = { [weak self] text, lane in self?.ask.learnCorrection(text, lane: lane) }
        commandPanel.learnedRoutes = { [weak self] in self?.ask.learnedRoutes ?? LearnedRoutes() }
        ask.openFollowUp = { [weak self] in self?.toggleCommandBox() }
        commandPanel.onPose = { [weak self] p in self?.renderer.react(.boxPose(p)) }
        commandPanel.onCarryOn = { [weak self] in
            guard let self else { return }
            self.ask.continueIn(self.ask.preferredHandoff)
        }
        commandPanel.onAddRepo = { [weak self] in self?.ask.addRepo() }

        digest = DigestController(host: .init(
            anchor: { [weak self] in self?.cardAvoidRect() ?? .zero },
            submit: { [weak self] item in self?.submit(item, preset: .gentle) },
            hostApp: { [weak self] id in self?.sessionApps[id] },
            react: { [weak self] r in self?.renderer.react(r) }))
        digest.onSummary = { [weak self] id, text in
            guard let m = self?.ask.card.model else { return }
            m.summarising.remove(id)
            if let text { m.sessionSummaries[id] = text }
        }
        onboarding = OnboardingController(host: .init(
            setLook: { [weak self] change in self?.setLook(change) },
            look: { [weak self] in self?.look ?? CharacterLook() },
            pose: { [weak self] s in self?.previewOverride = s },
            react: { [weak self] r in self?.renderer.react(r) },
            anchor: { [weak self] in self?.cardAvoidRect() ?? .zero },
            requestCalendar: { [weak self] in await self?.requestCalendarAccess() ?? false },
            calendarConnected: { CalendarSource.access == .granted },
            installHooks: { HookInstaller.install() },
            hooksInstalled: { HookInstaller.isInstalled },
            setPerch: { [weak self] on in self?.perchEnabled = on },
            setMoods: { [weak self] on in self?.moodsEnabled = on },
            setCap: { [weak self] n in self?.setSettings { $0.maxInterruptsPerDay = n } },
            cap: { [weak self] in self?.settings.maxInterruptsPerDay ?? 5 },
            setQuietHours: { [weak self] on in self?.setSettings { $0.quietHours = on ? QuietHours(start: (22, 0), end: (7, 0)) : nil } },
            quietHoursOn: { [weak self] in self?.settings.quietHours != nil },
            walkHome: { [weak self] in self?.wanderer.walkHome() }))
        // First run: let Hush settle in, then begin.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.onboarding.startIfNeeded() }
        HookInstaller.migratePath()
        DiagnosticsLog.write("launch: running from \(Bundle.main.bundlePath); login item status \(SMAppService.mainApp.status.rawValue)")
        agentStatus.onEvent = { [weak self] e in self?.agentEvent(e) }
        agentStatus.start()
        // Re-check "working in the background" as runs age past the threshold or you switch apps.
        agentTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.agentSessions.prune(now: Date())
                if !self.agentSessions.sessions.isEmpty { self.refresh() }
            }
        }
        agentTimer?.tolerance = 1
        moodTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.moodTick() }
        }

        focus.onChange = { [weak self] f in self?.focusChanged(f) }
        restorePause()
        applyFullScreenPreference()
        focus.start()

        calendar.onChange = { [weak self] m in
            self?.calendarMeetings = m
            self?.planReminders()
        }
        if CalendarSource.access == .granted { calendar.start() }
        Task { await triage.prewarm() }
        watchEnergy()

        updateAppearance()
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updateAppearance() } }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.placeAtHome() } }

        if defaults.bool(forKey: "HushDebugHooks") { installDebugHooks() }
        refresh()
    }

    /// Scriptable dev hooks, off by default (`defaults write dev.hush.Hush HushDebugHooks -bool YES`).
    /// Post a distributed notification named "dev.hush.debug" whose object is a command:
    ///   mail:ordinary|ask|vip|bulk · meeting:<minutes> · pose:<NN-name>|live · shoo · click · resolve
///   react:hover|unhover|poke|pat|unpat|lift|swing|drop
///   antic:copy|blow|ask|touch|shot|shake|flinch|perk|morning|dance|tuck|groove|ungroove|droopy|undroopy
///   move:perch|leave|walk|drop-on-front · mood:0-3 · play:inbox|command
    var isLifted = false
    /// Fastest horizontal fling during the current drag (pt/s): how dizzy it gets on landing.
    var dragPeakSpeed: CGFloat = 0

    /// A one-time explanation the first time a state appears (first week, after onboarding).
    func showFirstTip(for state: CharacterState, duck: Bool) {
        guard previewOverride == nil, let ob = onboarding, !ob.isActive else { return }
        let tip: FirstTip? = switch state {
        case .clock: .meetingClock
        case .hold: active?.item.kind == .agent ? .agentDone : .envelope
        case .hide where duck: .typingDuck
        default: nil
        }
        guard let tip, let text = ob.tip(tip) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.tipBubble.show(text, above: self.cardAvoidRect(), for: 8)
        }
    }

    func refresh() {
        defer { onRefresh?() }
        let now = Date()
        let input = PresenceInput(
            focus: focus.state, active: active, ambientPile: ambientPile,
            nextMeetingStart: MeetingReminderPlanner.nextStart(in: meetings, after: now),
            now: now, justShooed: justShooed,
            agentWorking: (ask?.isRunning ?? false)
                || agentSessions.workingInBackground(now: now, frontmostApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier))
        var state = previewOverride ?? Presence.state(for: input)

        // Hurry in from the edge, then settle into tapping on the glass.
        if state == .hurry && previewOverride == nil {
            if let since = hurrySince, now.timeIntervalSince(since) > 1.5 {
                state = .tap
            } else if hurrySince == nil {
                hurrySince = now
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.refresh() }
            }
        } else if state != .tap {
            hurrySince = nil
        }

        let duck = state == .hide && !focus.state.hidesCharacter && !previewAway
        if state != currentState || duck != currentDuck {
            currentDuck = duck
            showFirstTip(for: state, duck: duck)
            renderer.show(state, fromEdge: state == .hurry, duck: duck)
            currentState = state
        }
        setHidden(previewOverride == nil && focus.state.hidesCharacter)
    }

    /// Principle 3: during calls the character disappears completely (it'd show up in a screen share).
    /// It ducks into the hide pose first so the exit reads as intentional.
    func setHidden(_ hidden: Bool) {
        guard hidden != panelHidden else { return }
        panelHidden = hidden
        renderer.react(.visible(!hidden))
        if hidden {
            if wanderer?.isAway == true { wanderer.cancel(); placeAtHome() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self, self.panelHidden else { return }
                self.panel.orderOut(nil)
            }
        } else {
            panel.orderFrontRegardless()
        }
    }

    var pointerFast = false
    var pointerWasNear = true
    static let pointerReach: CGFloat = 450
    var lastMouse: NSPoint = .zero
    var lastMouseMove = Date.distantPast

    var hovered = false

    func updateAppearance() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        renderer.setDarkDesktop(dark)
    }

    // MARK: placement

    var screen: NSScreen? { NSScreen.main ?? NSScreen.screens.first }

}
