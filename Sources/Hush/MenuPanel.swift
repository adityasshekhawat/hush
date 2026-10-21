import AppKit
import HushCore
import HushMac
import SwiftUI

/// The menu bar panel, v2 (design guide 09b), 320 pt. It answers "does anything need me?" first: a header sentence
/// with Hush's face, then what waits (each with its one action), today's held-back number, three places (Agents,
/// While you were away, Ask Hush), and a footer that never moves: Pause, the screenshot switch, Settings. Set-once
/// things (connections, cost) live in Settings. Hold ⌥ while opening for developer items in the ··· menu.
@MainActor
final class MenuPanelModel: ObservableObject {
    @Published var heldToday = 0
    @Published var shownToday = 0
    /// Ask Hush questions this month (their cost is in History and Settings ▸ Ask Hush).
    @Published var monthQuestions = 0
    @Published var developer = false
    /// This Hush peeking, with the header's expression.
    @Published var avatar: NSImage?
}

struct MenuPanelActions {
    var openWaiting: (String) -> Void
    var moreWaiting: () -> Void
    var journal: () -> Void
    var sessions: () -> Void
    var away: () -> Void
    var history: () -> Void
    var settings: (SettingsSection) -> Void
    var pause: (PauseLength) -> Void
    var resume: () -> Void
    var close: () -> Void
    var resized: () -> Void
    var quit: () -> Void
}

struct MenuPanelView: View {
    @ObservedObject var model: MenuPanelModel
    @ObservedObject var settings: SettingsModel
    @ObservedObject var digest: DigestController
    @ObservedObject var updates: UpdateController
    let actions: MenuPanelActions

    private var app: AppController { settings.app }
    private var paused: Bool { app.pausedUntil != nil }

    var body: some View {
        let header = currentHeader
        VStack(alignment: .leading, spacing: 0) {
            headerRow(header)
            if paused {
                Button(action: actions.resume) { Label("Resume now", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(WidePill())
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
            waitingRows
            if let step = settings.setupLeft.first, app.waiting.isEmpty, !paused { setupRow(step).padding(.bottom, 8) }
            updateRow
            todayTile
            places.padding(.horizontal, 6).padding(.top, 2)
            Rectangle().fill(HushColor.hairline).frame(height: 1).padding(.horizontal, 12).padding(.vertical, 6)
            footer
        }
        .padding(.top, 6).padding(.bottom, 8)
        .background(GeometryReader { g in Color.clear.onChange(of: g.size) { actions.resized() } })
        .task(id: header.expression + app.look.rendererJSON) {
            model.avatar = await app.renderer.portrait(pose: "peek", expression: header.expression)
        }
    }

    // MARK: header

    private var currentHeader: MenuPanelText.Header {
        let s = situation
        var h = MenuPanelText.header(s, now: Date())
        // A rare find's only trace: a muted line when nothing else is going on.
        if s == .quiet, let line = app.rare?.panelLine { h.subtitle = line }
        return h
    }

    private var situation: MenuPanelText.Situation {
        let now = Date()
        let tuckedIn = (app.defaults.object(forKey: "lastTuckIn") as? Date).map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
        return MenuPanelText.situation(
            waiting: app.waiting.map(Self.label),
            pausedUntil: app.pausedUntil,
            setupLeft: settings.setupLeft.count,
            focused: app.focus.state.hidesCharacter && !app.focus.state.paused,
            asleep: (app.settings.quietHours?.contains(now, calendar: .current) ?? false) || tuckedIn)
    }

    /// "Claude in hush", "a meeting soon": what waits, in a few words, for the header's second line.
    static func label(_ d: Decision) -> String {
        let item = d.item
        switch item.kind {
        case .meeting: return "a meeting soon"
        case .mail: return item.senderName.map { "mail from \($0)" } ?? "mail"
        case .agent:
            if item.id.hasPrefix("ask:") { return "an answer" }
            if item.id.hasPrefix("browser:") { return "a browser task" }
            if item.id.hasPrefix("digest:") { return "while you were away" }
            let who = item.senderName == AgentKind.codex.senderName ? "Codex" : "Claude"
            return item.project.map { "\(who) in \($0)" } ?? who
        }
    }

    private func headerRow(_ h: MenuPanelText.Header) -> some View {
        HStack(spacing: 11) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(HushColor.lilacTint)
                if let a = model.avatar { Image(nsImage: a).resizable().scaledToFit() }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    switch h.dot {
                    case .needsYou: Circle().fill(HushColor.coral).frame(width: 8, height: 8)
                    case .paused: Circle().fill(Color.secondary.opacity(0.6)).frame(width: 8, height: 8)
                    case .none: EmptyView()
                    }
                    Text(h.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                }
                Text(h.subtitle).font(.system(size: 12.5)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { popMenu(moreMenu) } label: {
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28).background(HushColor.quietFill, in: Circle()).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("More")
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 10)
    }

    // MARK: what waits

    @ViewBuilder private var waitingRows: some View {
        let all = app.waiting
        if !all.isEmpty {
            let (n, more) = MenuPanelText.waitingRows(all.count)
            VStack(spacing: 6) {
                ForEach(Array(all.prefix(n)), id: \.id) { d in waitingRow(d) }
                if more > 0 {
                    Button(action: actions.moreWaiting) {
                        HStack {
                            Text("and \(more) more").font(.system(size: 13.5, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10).frame(height: 36)
                        .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6).padding(.bottom, 8)
        }
    }

    private func waitingRow(_ d: Decision) -> some View {
        let v = EnvelopeVariant(d)
        let join = d.item.kind == .meeting && d.item.openURL?.scheme == "https"
        return HStack(spacing: 11) {
            PanelTile(symbol: v.symbol, tone: v.tone)
            VStack(alignment: .leading, spacing: 1) {
                Text(v.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(v.source).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(join ? "Join" : "Open") { actions.openWaiting(d.id) }.buttonStyle(HushPill(kind: .primary))
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: setup nudge

    private func setupRow(_ step: ConnectStep) -> some View {
        let (symbol, title, line, button): (String, String, String, String) = switch step {
        case .calendar: ("calendar", "Connect Calendar", "So I can nudge you before meetings", "Connect")
        case .claudeCode: ("terminal", "Watch Claude Code", "So I can tell you when it needs you", "Connect")
        case .askHotkey: ("command", "Try ⌘⇧H", "Ask me anything, from any app", "Try it")
        }
        return NudgeRow(symbol: symbol, title: title, line: line) {
            Button(button) { actions.close(); settings.doSetup(step) }.buttonStyle(HushPill(kind: .primary))
        }
    }

    // MARK: new versions (ADR-036)

    @ViewBuilder private var updateRow: some View {
        switch updates.status {
        case .available(let r):
            NudgeRow(symbol: "arrow.down.circle", title: "Hush \(r.version) is out", line: "You have \(updates.current) · What's new",
                     onText: { actions.close(); NSWorkspace.shared.open(r.page) }) {
                if updates.sourceFolder != nil {
                    Button("Update") { actions.close(); updates.update() }.buttonStyle(HushPill(kind: .primary))
                        .help("Opens Terminal in the folder you built Hush from and runs git pull, then ./scripts/bundle.sh")
                } else {
                    CopyCommandButton { updates.update() }
                }
            }
            .padding(.bottom, 8)
        case .checking:
            NudgeRow(symbol: "arrow.down.circle", title: "Checking for a new version…", line: "Asking GitHub") {
                ProgressView().controlSize(.small)
            }
            .padding(.bottom, 8)
        case .upToDate:
            NudgeRow(symbol: "checkmark.circle", title: "You have the latest Hush", line: "Version \(updates.current)") { EmptyView() }
                .padding(.bottom, 8)
        case .failed:
            NudgeRow(symbol: "exclamationmark.circle", title: "Couldn't reach GitHub", line: "Try again in a while") { EmptyView() }
                .padding(.bottom, 8)
        case .idle:
            if updates.consent == nil, app.waiting.isEmpty, settings.setupLeft.isEmpty, !paused {
                NudgeRow(symbol: "arrow.down.circle", title: "Tell you about updates?",
                         line: "I'd check GitHub once a day. Nothing about you is sent") {
                    HStack(spacing: 4) {
                        Button("No") { updates.consent = false }.buttonStyle(HushPill(kind: .quiet))
                        Button("Yes") { updates.consent = true }.buttonStyle(HushPill(kind: .primary))
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: today

    private var todayTile: some View {
        Button(action: actions.journal) {
            HStack(spacing: 12) {
                if let t = MenuPanelText.today(held: model.heldToday, shown: model.shownToday) {
                    Text(t.number).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(HushColor.lilacInk)
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 1) {
                        Text("held back today").font(.system(size: 13, weight: .semibold))
                        Text(t.line).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(MenuPanelText.todayEmpty.0).font(.system(size: 13, weight: .semibold))
                        Text(MenuPanelText.todayEmpty.1).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
            }
            .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 10)
            .frame(minHeight: 52)
            .background(HushColor.lilacTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .opacity(paused ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .help("What I saw: everything I looked at, what I did and why")
        .padding(.horizontal, 6).padding(.bottom, 4)
    }

    // MARK: places

    private var places: some View {
        let watchingClaude = HookInstaller.isInstalled, watchingCodex = HookInstaller.isInstalled(.codex)
        let counts = app.agentSessions.counts(now: Date())
        let agents = MenuPanelText.agents(
            watching: watchingClaude || watchingCodex,
            needsUpdate: (watchingClaude && HookInstaller.needsUpdate(.claude)) || (watchingCodex && HookInstaller.needsUpdate(.codex)),
            running: counts.running, needsYou: counts.needsYou)
        return VStack(spacing: 0) {
            PlaceRow(symbol: "terminal", title: "Agents", line: agents.line, dot: Self.dot(agents.state)) {
                switch agents.state {
                case .notConnected, .needsUpdate: actions.settings(.connections)
                default: actions.sessions()
                }
            }
            if digest.unseen, let w = digest.window {
                PlaceRow(symbol: "clock.arrow.circlepath", title: "While you were away",
                         line: MenuPanelText.away(sessions: digest.digests.count, minutes: Int(w.duration / 60)), action: actions.away)
            }
            PlaceRow(symbol: "bubble.left", title: "Ask Hush", line: MenuPanelText.ask(questionsThisMonth: model.monthQuestions),
                     trailing: "⌘⇧H", action: actions.history)
        }
    }

    private static func dot(_ s: MenuPanelText.AgentsState) -> Color? {
        switch s {
        case .needsYou, .needsUpdate: HushColor.coral
        case .running: HushColor.done
        case .notConnected, .idle: nil
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button { popMenu(pauseMenu) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "moon").font(.system(size: 12, weight: .semibold))
                    Text(paused ? "Change pause" : "Pause")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(HushPill(kind: .secondary))
            .help("⌥⇧⌘H puts away what I'm showing, or pauses me for an hour")
            Spacer()
            screenshotButton
            Button { actions.settings(.general) } label: { Label("Settings", systemImage: "gearshape") }
                .buttonStyle(HushPill(kind: .quiet))
        }
        .padding(.horizontal, 12).padding(.top, 2)
    }

    /// One click: let Hush into screenshots and shares, or keep it out (the default).
    private var screenshotButton: some View {
        let shown = !settings.hiddenFromCapture.wrappedValue
        return Button { settings.hiddenFromCapture.wrappedValue = shown } label: {
            Image(systemName: shown ? "eye" : "eye.slash")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(shown ? AnyShapeStyle(HushColor.lilacInk) : AnyShapeStyle(.secondary))
                .frame(width: 28, height: 28)
                .background(shown ? HushColor.lilacTint : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(shown ? "I show in screenshots and screen shares. Click to hide me" : "I'm left out of screenshots and screen shares. Click to show me")
        .accessibilityLabel(shown ? "Hide me from screenshots" : "Show me in screenshots")
    }

    // MARK: menus

    private var pauseMenu: [MenuItem] {
        PauseLength.allCases.map { l in
            MenuItem(title: l == .untilTomorrow ? "Until tomorrow morning" : "For \(l.title)") { actions.pause(l) }
        }
    }

    private var moreMenu: [MenuItem] {
        var items = [
            MenuItem(title: "Show me in screenshots", checked: !settings.hiddenFromCapture.wrappedValue) {
                settings.hiddenFromCapture.wrappedValue.toggle()
            },
            MenuItem(title: "Open Hush's settings…", key: ",") { actions.settings(.general) },
            MenuItem(title: "Check for updates…") { Task { await updates.check(manual: true) } },
            .separator,
            MenuItem(title: "Replay the intro") { actions.close(); settings.replayIntro() },
        ]
        if model.developer {
            items += [
                .separator,
                MenuItem(title: "Simulate VIP mail") { settings.app.simulate(.vip) },
                MenuItem(title: "Simulate a meeting in 2 min") { settings.app.simulateMeeting(inMinutes: 2) },
                MenuItem(title: "Tuck in") { settings.app.antics.tuckIn() },
                MenuItem(title: "Developer settings…") { actions.settings(.developer) },
            ]
        }
        items += [.separator, MenuItem(title: "Quit Hush", key: "q", action: actions.quit)]
        return items
    }
}

/// A one-line ask with its action on the right: setup steps, new versions. Tapping the words can do something else.
private struct NudgeRow<Trailing: View>: View {
    let symbol: String
    let title: String
    let line: String
    var onText: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 11) {
            PanelTile(symbol: symbol, tone: .lilac)
            let words = VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .semibold)).lineLimit(2)
                Text(line).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            if let onText {
                Button(action: onText) { words.contentShape(Rectangle()) }.buttonStyle(.plain)
            } else {
                words
            }
            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .padding(.horizontal, 6)
    }
}

/// Without a known clone: copy the update command, and say so.
private struct CopyCommandButton: View {
    let copy: () -> Void
    @State private var copied = false
    var body: some View {
        Button(copied ? "Copied" : "Copy command") { copy(); copied = true }
            .buttonStyle(HushPill(kind: .primary))
            .help("git pull --ff-only && ./scripts/bundle.sh, to run in the folder you cloned Hush into")
    }
}

/// A 26 pt icon tile, radius 7 (the panel's rows).
private struct PanelTile: View {
    let symbol: String
    var tone: Tone? = nil

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tone.map { AnyShapeStyle($0.text) } ?? AnyShapeStyle(.primary))
            .frame(width: 26, height: 26)
            .background(tone?.fill ?? HushColor.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// One of the three places: tile, title, one line, then an optional dot or shortcut and a chevron. Highlights on hover.
private struct PlaceRow: View {
    let symbol: String
    let title: String
    let line: String
    var dot: Color? = nil
    var trailing: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                PanelTile(symbol: symbol)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .medium))
                    Text(line).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 7) {
                    if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                    if let trailing { Text(trailing).font(.system(size: 12)).foregroundStyle(.secondary) }
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(hovering ? HushColor.quietFill : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The paused state's one big button: full width, primary.
private struct WidePill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(HushColor.primaryText)
            .frame(height: 28)
            .background(Capsule().fill(HushColor.primaryFill))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Native menus (Pause, ···)

struct MenuItem {
    var title = ""
    var checked = false
    var key = ""
    var isSeparator = false
    var action: () -> Void = {}

    init(title: String, checked: Bool = false, key: String = "", action: @escaping () -> Void) {
        self.title = title; self.checked = checked; self.key = key; self.action = action
    }
    private init(separator: Bool) { isSeparator = separator }
    static var separator: MenuItem { MenuItem(separator: true) }
}

/// Pops a native menu under the pointer. The items' closures run on the main actor.
@MainActor
func popMenu(_ items: [MenuItem]) {
    let menu = NSMenu()
    menu.autoenablesItems = false
    let targets = items.map { MenuTarget($0.action) }
    for (item, target) in zip(items, targets) {
        if item.isSeparator { menu.addItem(.separator()); continue }
        let m = NSMenuItem(title: item.title, action: #selector(MenuTarget.run), keyEquivalent: item.key)
        m.target = target
        m.state = item.checked ? .on : .off
        m.representedObject = target   // keeps the target alive as long as the menu
        menu.addItem(m)
    }
    menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
}

private final class MenuTarget: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func run() { action() }
}

/// The panel's window: hangs under the status item, closes when you click elsewhere.
@MainActor
final class MenuPanel {
    let model = MenuPanelModel()
    private var panel: NSPanel?
    private var monitors: [Any] = []
    private let settings: SettingsModel
    var actions: MenuPanelActions?

    init(settings: SettingsModel) { self.settings = settings }

    var isOpen: Bool { panel?.isVisible ?? false }

    func toggle(below button: NSStatusBarButton) { isOpen ? close() : open(below: button) }

    func open(below button: NSStatusBarButton) {
        model.developer = NSEvent.modifierFlags.contains(.option)
        settings.reload()
        Task {
            let e = settings.app.engine
            if let d = try? await e.daySummary() { model.heldToday = d.heldBack; model.shownToday = d.shown }
            let tasks = ((try? await e.agentTasks(limit: 500)) ?? []).filter {
                $0.repo != "action" && Calendar.current.isDate($0.startedAt, equalTo: Date(), toGranularity: .month)
            }
            model.monthQuestions = tasks.count
            place(below: button)
        }
        let p = panel ?? make()
        panel = p
        place(below: button)
        p.orderFrontRegardless()
        let close: (NSEvent) -> Void = { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.close() } }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: close) as Any)
        DiagnosticsLog.write("menu: panel opened")
    }

    func close() {
        settings.app.updates.settle()
        panel?.orderOut(nil)
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    /// Keeps the panel hanging from the status item as its content grows or shrinks.
    func fit() {
        guard isOpen, let p = panel, let h = p.contentView else { return }
        let size = h.fittingSize
        var f = p.frame
        f.origin.y += f.height - size.height
        f.size = size
        p.setFrame(f, display: true)
    }

    private func place(below button: NSStatusBarButton) {
        guard let p = panel, let h = p.contentView, let bw = button.window else { return }
        let size = h.fittingSize
        let b = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let vf = NSScreen.main?.visibleFrame ?? .zero
        let x = min(max(vf.minX + 8, b.midX - size.width / 2), vf.maxX - size.width - 8)
        p.setFrame(NSRect(x: x, y: b.minY - size.height - 4, width: size.width, height: size.height), display: true)
    }

    private func make() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        let a = actions ?? .init(openWaiting: { _ in }, moreWaiting: {}, journal: {}, sessions: {}, away: {}, history: {},
                                 settings: { _ in }, pause: { _ in }, resume: {}, close: {}, resized: {}, quit: {})
        let wrapped = MenuPanelActions(
            openWaiting: { [weak self] id in self?.close(); a.openWaiting(id) },
            moreWaiting: { [weak self] in self?.close(); a.moreWaiting() },
            journal: { [weak self] in self?.close(); a.journal() },
            sessions: { [weak self] in self?.close(); a.sessions() },
            away: { [weak self] in self?.close(); a.away() },
            history: { [weak self] in self?.close(); a.history() },
            settings: { [weak self] s in self?.close(); a.settings(s) },
            pause: { [weak self] l in self?.close(); a.pause(l) },
            resume: { [weak self] in self?.close(); a.resume() },
            close: { [weak self] in self?.close() },
            resized: { [weak self] in self?.fit() },
            quit: a.quit)
        let view = MenuPanelView(model: model, settings: settings, digest: settings.app.digest, updates: settings.app.updates,
                                 actions: wrapped)
            .frame(width: 320, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .hushSurface(radius: 14, shadow: false)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = [.intrinsicContentSize]
        p.contentView = host
        ArrowCursor.keep(in: host)
        return p
    }
}
