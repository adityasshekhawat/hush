import AppKit
import HushCore
import HushMac
import SwiftUI

/// The menu bar panel (docs/design-guide.md §5.10), 320 pt: "Hush" and its status word, the held-back row, what
/// it's holding, quick buttons, connections, then Settings and Quit. Hold ⌥ while opening for developer items.
@MainActor
final class MenuPanelModel: ObservableObject {
    @Published var heldToday = 0
    @Published var shownToday = 0
    @Published var rulesLearned = 0
    /// Ask Hush this month: questions and spend (the one place costs show, besides History).
    @Published var monthQuestions = 0
    @Published var monthCost = 0.0
    @Published var developer = false
    @Published var tick = 0
}

struct MenuPanelActions {
    var showHeld: () -> Void
    var openCard: () -> Void
    var digest: () -> Void
    var history: () -> Void
    var sessions: () -> Void
    var settings: (SettingsSection) -> Void
    var pause: (PauseLength) -> Void
    var resume: () -> Void
    var quit: () -> Void
}

struct MenuPanelView: View {
    @ObservedObject var model: MenuPanelModel
    @ObservedObject var settings: SettingsModel
    let actions: MenuPanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hush").font(HushFont.cardTitle)
                Spacer()
                Text(settings.statusWord).font(HushFont.footer).foregroundStyle(.secondary)
            }
            heldRow
            if !settings.app.waiting.isEmpty { holding }
            if settings.agentWorking {
                Label("Claude is working somewhere you're not looking", systemImage: "ellipsis.bubble")
                    .font(HushFont.subtitle).foregroundStyle(HushColor.working)
            }
            if model.monthQuestions > 0 {
                Button(action: actions.history) {
                    HStack(spacing: 4) {
                        Text("Ask Hush this month: \(model.monthQuestions) \(model.monthQuestions == 1 ? "question" : "questions") · $" + String(format: "%.2f", model.monthCost))
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                    }
                    .font(HushFont.footer).foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Every question with its model, time and cost")
            }
            if let line = settings.app.rare?.panelLine {
                Text(line).font(HushFont.footer).foregroundStyle(.tertiary)
            }
            quickButtons
            pauseRow
            Divider()
            VStack(spacing: 6) {
                ForEach(settings.connections) { c in ConnectionRow(model: settings, c: c) }
            }
            if model.developer { developer }
            Divider()
            HStack {
                Button { actions.settings(.general) } label: { Label("Settings…", systemImage: "gearshape") }
                    .buttonStyle(HushPill(kind: .quiet))
                Spacer()
                Button("Quit Hush", action: actions.quit).buttonStyle(HushPill(kind: .quiet))
            }
        }
    }

    /// "63 held back today · 4 shown · 2 rules learned": opens the held list.
    private var heldRow: some View {
        Button(action: actions.showHeld) {
            HStack(spacing: 6) {
                Text("\(model.heldToday)").font(HushFont.number(16)).foregroundStyle(HushColor.lilacInk)
                Text("held back today · \(model.shownToday) shown · \(model.rulesLearned) \(model.rulesLearned == 1 ? "rule" : "rules") learned")
                    .font(HushFont.footer).foregroundStyle(HushColor.lilacInk).lineLimit(1).minimumScaleFactor(0.9)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(HushColor.lilacInk.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(HushColor.lilacTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var holding: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(settings.app.waiting.prefix(4), id: \.id) { d in
                let v = EnvelopeVariant(d)
                Button(action: actions.openCard) {
                    HStack(spacing: 8) {
                        IconTile(symbol: v.symbol, tone: v.tone)
                        Text(v.title).font(HushFont.body).lineLimit(1)
                        Spacer()
                    }
                    .frame(height: 26)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickButtons: some View {
        HStack(spacing: 6) {
            Button { actions.digest() } label: { Label("While you were away", systemImage: "moon.fill") }
                .buttonStyle(HushPill(kind: .secondary))
            Button { actions.sessions() } label: { Label("Sessions", systemImage: "terminal") }.buttonStyle(HushPill(kind: .secondary))
            Button("History", action: actions.history).buttonStyle(HushPill(kind: .secondary))
            if !settings.setupLeft.isEmpty {
                Button("Setup: \(settings.setupLeft.count) left") { actions.settings(.setup) }.buttonStyle(HushPill(kind: .secondary))
            }
        }
    }

    /// One action to take Hush away (ADR-022). ⌥⇧⌘H does the same.
    private var pauseRow: some View {
        HStack(spacing: 6) {
            if settings.app.pausedUntil != nil {
                Image(systemName: "pause.circle.fill").foregroundStyle(.secondary)
                Text(settings.statusWord).font(HushFont.footer).foregroundStyle(.secondary)
                Spacer()
                Button("Resume", action: actions.resume).buttonStyle(HushPill(kind: .primary, height: 24))
            } else {
                Text("Pause").font(HushFont.footer).foregroundStyle(.secondary)
                ForEach(PauseLength.allCases, id: \.self) { l in
                    Button(l == .untilTomorrow ? "Tomorrow" : l.title) { actions.pause(l) }
                        .buttonStyle(HushPill(kind: .secondary, height: 24))
                }
                Spacer()
            }
        }
        .help("⌥⇧⌘H puts away what I'm showing, or pauses me for an hour")
    }

    private var developer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Developer").font(HushFont.tag).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Button("VIP mail") { settings.app.simulate(.vip) }.buttonStyle(HushPill(kind: .secondary, height: 24))
                Button("Meeting in 2") { settings.app.simulateMeeting(inMinutes: 2) }.buttonStyle(HushPill(kind: .secondary, height: 24))
                Button("Tuck in") { settings.app.antics.tuckIn() }.buttonStyle(HushPill(kind: .secondary, height: 24))
            }
            Button("More in Settings ▸ Developer") { actions.settings(.developer) }.buttonStyle(HushPill(kind: .quiet))
        }
    }
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
            model.rulesLearned = (try? await e.rules().count) ?? 0
            let tasks = ((try? await e.agentTasks(limit: 500)) ?? []).filter {
                $0.repo != "action" && Calendar.current.isDate($0.startedAt, equalTo: Date(), toGranularity: .month)
            }
            model.monthQuestions = tasks.count
            model.monthCost = tasks.map(\.costUSD).reduce(0, +)
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
        panel?.orderOut(nil)
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
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
        let a = actions ?? .init(showHeld: {}, openCard: {}, digest: {}, history: {}, sessions: {}, settings: { _ in }, pause: { _ in }, resume: {}, quit: {})
        let wrapped = MenuPanelActions(
            showHeld: { [weak self] in self?.close(); a.showHeld() },
            openCard: { [weak self] in self?.close(); a.openCard() },
            digest: { [weak self] in self?.close(); a.digest() },
            history: { [weak self] in self?.close(); a.history() },
            sessions: { [weak self] in self?.close(); a.sessions() },
            settings: { [weak self] s in self?.close(); a.settings(s) },
            pause: { [weak self] l in self?.close(); a.pause(l) },
            resume: { [weak self] in self?.close(); a.resume() },
            quit: a.quit)
        let view = MenuPanelView(model: model, settings: settings, actions: wrapped)
            .padding(.horizontal, HushSpace.cardH).padding(.vertical, HushSpace.cardV)
            .frame(width: 320, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HushColor.hairline, lineWidth: 0.5))
        p.contentView = NSHostingView(rootView: view)
        return p
    }
}
