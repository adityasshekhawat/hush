import AppKit
import HushCore
import HushMac

/// The menu bar item (docs/design-guide.md §5.10): the designer's template glyph for Hush's state, and a click opens
/// the panel (MenuPanel). Settings live in their own window (SettingsWindow). The held-back number never goes on
/// the glyph; an optional waiting count does, capped at "9+".
@MainActor
final class MenuBar: NSObject {
    /// Variable length so the optional count fits beside the glyph.
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let app: AppController
    let settings: SettingsModel
    private let panel: MenuPanel
    private let settingsWindow: SettingsWindowController
    private let wardrobe: WardrobeWindowController
    /// The designer's template glyphs, one per state (assets/brand/menu-bar).
    private let glyphs: [MenuBarBadge.Glyph: NSImage] = Dictionary(uniqueKeysWithValues: MenuBarBadge.Glyph.allCases.map { g in
        (g, MenuBarIcon.template(g) ?? MenuBarIcon.image(g == .idle ? .outline : .filled))
    })
    private var shown: MenuBarBadge?
    private var waitingCount = 0

    /// Off by default: the glyph alone says "something's here" without counting at you.
    private var showsCount: Bool { app.defaults.bool(forKey: "menuBarCount") }

    init(app: AppController) {
        self.app = app
        settings = SettingsModel(app: app)
        panel = MenuPanel(settings: settings)
        settingsWindow = SettingsWindowController(model: settings)
        wardrobe = WardrobeWindowController(model: settings)
        super.init()
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        item.button?.target = self
        item.button?.action = #selector(clicked)
        panel.actions = MenuPanelActions(
            showHeld: { [weak app] in
                app?.showHeldBack(.day, list: true)
            },
            openCard: { [weak app] in app?.showCard() },
            digest: { [weak app] in
                guard let app else { return }
                if app.digest.enabled { app.digest.showNow() } else { app.digest.toggleWithConsent() }
            },
            history: { [weak app] in app?.ask.showHistory() },
            journal: { [weak app] in app?.journal.show() },
            sessions: { [weak app] in app?.ask.showSessions() },
            settings: { [weak self] s in self?.settingsWindow.show(s) },
            pause: { [weak app] l in app?.pause(l) },
            resume: { [weak app] in app?.resume() },
            quit: { NSApp.terminate(nil) })
        app.onWaitingChange = { [weak self] n in self?.setHolding(count: n) }
        app.onRefresh = { [weak self] in self.map { $0.setHolding(count: $0.waitingCount) } }
        app.openSettings = { [weak self] s in self?.settingsWindow.show(s) }
        app.openPanel = { [weak self] in self?.clicked() }
        app.openWardrobe = { [weak self] in self?.wardrobe.show() }
        setHolding(count: app.waiting.count)
    }

    @objc private func clicked() {
        guard let button = item.button else { return }
        panel.toggle(below: button)
    }

    /// The glyph for Hush's state. Only touches the status item when what it shows changes.
    func setHolding(count: Int) {
        waitingCount = count
        let now = Date()
        let tuckedIn = (app.defaults.object(forKey: "lastTuckIn") as? Date).map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
        let badge = MenuBarBadge(waiting: count, showCount: showsCount,
                                 meetingWaiting: app.waiting.contains { $0.item.kind == .meeting },
                                 focused: app.focus.state.hidesCharacter && !app.focus.state.paused,
                                 asleep: (app.settings.quietHours?.contains(now, calendar: .current) ?? false) || tuckedIn
                                    || app.focus.state.paused)
        guard badge != shown, let button = item.button else { return }
        shown = badge
        button.image = glyphs[badge.glyph]
        button.title = badge.count ?? ""
        button.imagePosition = badge.count == nil ? .imageOnly : .imageLeading
        button.setAccessibilityLabel(badge.holding ? "Hush, holding something" : "Hush")
    }
}
