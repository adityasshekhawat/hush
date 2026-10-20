import AppKit
import HushCore
import HushMac

/// Rare finds in the app (docs/design-guide.md §6b): checks once a minute, rolls at the right moments, dresses Hush
/// for the day, and remembers what's been found. Silent: the only trace is a muted line in the menu bar panel.
@MainActor
final class RareFindsController {
    private unowned let app: AppController
    private let defaults = UserDefaults.standard
    private(set) var state: RareState
    private var timer: Timer?
    private var lastTickDay: Date?

    init(app: AppController) {
        self.app = app
        state = (defaults.data(forKey: "rareFinds")).flatMap { try? JSONDecoder().decode(RareState.self, from: $0) } ?? RareState()
        if defaults.object(forKey: "installDate") == nil { defaults.set(Date(), forKey: "installDate") }
    }

    func start() {
        apply()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 10
        tick()
    }

    // MARK: moments

    private var context: RareContext {
        let now = Date()
        let quiet = app.settings.quietHours?.contains(now, calendar: .current) ?? false
        let busy = app.focus.state.hidesCharacter || app.focus.state.typing || quiet || !app.waiting.isEmpty
        let south = (TimeZone.current.identifier.hasPrefix("Australia") || TimeZone.current.identifier.hasPrefix("Pacific/Auckland")
                     || TimeZone.current.identifier.hasPrefix("America/Argentina") || TimeZone.current.identifier.hasPrefix("America/Sao_Paulo")
                     || TimeZone.current.identifier.hasPrefix("Africa/Johannesburg"))
        return RareContext(now: now, busy: busy, installDate: defaults.object(forKey: "installDate") as? Date ?? now, southernHemisphere: south)
    }

    private func tick() {
        let ctx = context
        if !RareFinds.expire(&state, now: ctx.now).isEmpty { apply(); save() }
        guard !app.focus.state.away else { return }
        let cal = Calendar.current
        // A new day of activity: dated finds, coming back after days away, a quiet week.
        if lastTickDay.map({ !cal.isDate($0, inSameDayAs: ctx.now) }) ?? true {
            lastTickDay = ctx.now
            let lastActive = defaults.object(forKey: "rareLastActive") as? Date
            roll(.dayStart, ctx)
            if let last = lastActive, !cal.isDate(last, inSameDayAs: ctx.now) {
                let away = ctx.now.timeIntervalSince(last) / 86_400
                roll(.firstUnlock(daysAway: away, weekday: cal.component(.weekday, from: ctx.now), hour: cal.component(.hour, from: ctx.now)), ctx)
            }
            if cal.component(.weekday, from: ctx.now) == 2 { checkQuietWeek(ctx) }
        }
        defaults.set(ctx.now, forKey: "rareLastActive")
        let h = cal.component(.hour, from: ctx.now)
        if h < 10 { roll(.morning, ctx) }
        if (13..<17).contains(h) { roll(.afternoon, ctx) }
        if (1..<5).contains(h) { roll(.lateNight, ctx) }
        roll(.springDay, ctx)
    }

    /// Last week needed no interrupts at all, though Hush was busy holding things back: a halo.
    private func checkQuietWeek(_ ctx: RareContext) {
        Task {
            let lastWeek = ctx.now.addingTimeInterval(-7 * 86_400)
            guard let w = try? await app.engine.weekSummary(now: lastWeek), w.shown == 0, w.heldBack > 0 else { return }
            roll(.quietWeek, ctx)
        }
    }

    func dragged() {
        if !RareFinds.expire(&state, now: Date(), dragged: true).isEmpty { apply(); save() }
        roll(.drag, context)
    }

    func asked() {
        let n = defaults.integer(forKey: "askCount") + 1
        defaults.set(n, forKey: "askCount")
        roll(.askCount(n), context)
    }

    private func roll(_ moment: RareMoment, _ ctx: RareContext) {
        let firstTime = Set(RareFinds.all.map(\.id).filter { state.found[$0] == nil })
        let won = RareFinds.roll(moment, state: &state, ctx: ctx)
        guard !won.isEmpty else { return }
        save()
        apply()
        DiagnosticsLog.write("rare: found \(won.joined(separator: ", "))")
        if let id = won.first, firstTime.contains(id) { app.renderer.react(.rareFirst(id)) }
    }

    // MARK: wearing

    /// Recordings show the plain brand look (debug hooks): rare pieces aren't worn meanwhile.
    var suppressed = false { didSet { apply() } }

    /// Today's rare pieces replace the same slot; your own piece comes back afterwards.
    private func apply() {
        var today: [String: String] = [:]
        if !suppressed {
            for id in state.wearing.keys { if let slot = Wardrobe.piece(id)?.slot { today[slot.rawValue] = id } }
        }
        guard today != app.look.todayOutfit else { return }
        app.look.todayOutfit = today
        app.renderer.apply(app.look)
    }

    private func save() {
        if let d = try? JSONEncoder().encode(state) { defaults.set(d, forKey: "rareFinds") }
    }

    var panelLine: String? { RareFinds.panelLine(state, now: Date()) }
    var found: Set<String> { Set(state.found.keys) }

    /// Debug: find a piece now (ignores odds and the daily cap).
    func debugFind(_ id: String) {
        guard Wardrobe.piece(id)?.source == .rare else { return }
        state.found[id] = state.found[id] ?? Date()
        state.wearing[id] = RareFinds.leavesAt(id, from: Date(), calendar: .current)
        state.lastFindDay = Calendar.current.startOfDay(for: Date())
        state.lastFindPhrase = RareFinds.find(id)?.phrase
        save(); apply()
        app.renderer.react(.rareFirst(id))
    }
}
