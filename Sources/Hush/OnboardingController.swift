import AppKit
import HushCore
import HushMac
import SwiftUI

/// The first-run journey (docs/onboarding-plan.md). Hush guides; a card carries the words.
/// Every step is skippable; progress is saved, so it resumes after a quit and can be replayed from the menu.
@MainActor
final class OnboardingController: ObservableObject {
    struct Host {
        var setLook: ((inout CharacterLook) -> Void) -> Void
        var look: () -> CharacterLook
        var pose: (CharacterState?) -> Void
        var react: (Reaction) -> Void
        var anchor: () -> NSRect
        var requestCalendar: () async -> Bool
        var calendarConnected: () -> Bool
        var installHooks: () -> Void
        var hooksInstalled: () -> Bool
        var setPerch: (Bool) -> Void
        var setMoods: (Bool) -> Void
        var setCap: (Int) -> Void
        var cap: () -> Int
        var setQuietHours: (Bool) -> Void
        var quietHoursOn: () -> Bool
        var walkHome: () -> Void
    }

    @Published private(set) var step: OnboardingStep = .arrival
    @Published var progress: OnboardingProgress
    @Published var cap: Double = 5
    @Published var quietHours = false

    private let host: Host
    private let panel = OnboardingPanel()
    private let defaults = UserDefaults.standard
    let claudeInstalled = ClaudeCodeRunner.locateClaude() != nil

    var isActive: Bool { panel.isOpen }
    var preset: OnboardingPreset { .from(progress.personas, claudeInstalled: claudeInstalled) }

    init(host: Host) {
        self.host = host
        if let d = defaults.data(forKey: "onboarding"), let p = try? JSONDecoder().decode(OnboardingProgress.self, from: d) {
            progress = p
        } else {
            progress = OnboardingProgress(firstLaunch: Date())
        }
        panel.onRelayout = { [weak self] in self?.reposition() }
    }

    // MARK: flow

    func startIfNeeded() {
        guard progress.shouldStart else { return }
        start(from: progress.lastStep)
    }

    func start(from s: OnboardingStep = .arrival) {
        cap = Double(host.cap())
        quietHours = host.quietHoursOn()
        panel.show(view: OnboardingView(controller: self))
        go(s)
        DiagnosticsLog.write("onboarding: started at \(s)")
    }

    func next() {
        guard let n = OnboardingStep(rawValue: step.rawValue + 1) else { finish(); return }
        go(n)
    }

    func back() {
        guard let p = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        go(p)
    }

    func skipAll() {
        progress.skipped = true
        save()
        DiagnosticsLog.write("onboarding: skipped at \(step)")
        close()
    }

    private func go(_ s: OnboardingStep) {
        step = s
        progress.lastStep = s
        save()
        switch s {
        case .arrival:
            host.pose(.stand)
            host.react(.wave)
        case .look, .question, .connect, .quiet:
            host.pose(.stand)
        case .sayHi:
            // Hovering a standing Hush makes it hop; patting and dragging work as everywhere else.
            host.pose(.stand)
        case .goodbye:
            applyPreset()
            host.pose(nil)
            host.react(.handOver)
        }
        reposition()
    }

    private func finish() {
        progress.finished = true
        save()
        DiagnosticsLog.write("onboarding: finished (personas \(progress.personas.map(\.rawValue).sorted()), connected \(progress.connected.map(\.rawValue).sorted()))")
        close()
        host.walkHome()
    }

    private func close() {
        panel.close()
        host.pose(nil)
    }

    private func applyPreset() {
        let p = preset
        host.setPerch(p.perch)
        host.setMoods(p.moods)
        host.setCap(Int(cap.rounded()))
        host.setQuietHours(quietHours)
    }

    // MARK: step actions

    func togglePersona(_ p: Persona) {
        if progress.personas.contains(p) { progress.personas.remove(p) } else { progress.personas.insert(p) }
        if progress.personas == [.company] || (progress.personas.contains(.juggler) && !progress.personas.contains(.company)) {
            cap = Double(preset.maxInterruptsPerDay)
        }
        save()
    }

    func surpriseMe() {
        host.setLook { l in
            l.body = CharacterLook.bodies.randomElement()!
            l.palette = CharacterLook.palettes.randomElement()!
            l.topper = CharacterLook.toppers.randomElement()!
            // Free pieces only in onboarding (design guide §6a: packs never appear here).
            l.outfit = [:]
            if let p = LookPicker.wears.compactMap(Wardrobe.piece).randomElement(), Bool.random() { l.outfit[p.slot.rawValue] = p.id }
        }
        host.react(.poke)
        objectWillChange.send()
    }

    func setLook(_ change: (inout CharacterLook) -> Void) {
        host.setLook(change)
        objectWillChange.send()
    }

    var look: CharacterLook { host.look() }

    /// Called by the app when you hover, pat or drop Hush (the "Say hi" step ticks them off).
    func observed(_ gesture: String) {
        guard step == .sayHi, !progress.sayHi.contains(gesture) else { return }
        progress.sayHi.insert(gesture)
        save()
        if progress.sayHi.count == 3 {
            host.react(.handOver)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                if self?.step == .sayHi { self?.next() }
            }
        }
    }

    func connect(_ c: ConnectStep) {
        switch c {
        case .calendar:
            Task {
                let ok = await host.requestCalendar()
                if ok { progress.connected.insert(.calendar) } else { progress.declined.insert(.calendar) }
                save()
            }
        case .claudeCode:
            host.installHooks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.refreshConnected() }
        case .askHotkey:
            break   // completes when you actually press ⌘⇧H (observedHotkey)
        }
    }

    func observedHotkey() {
        guard !progress.connected.contains(.askHotkey) else { return }
        progress.connected.insert(.askHotkey)
        save()
    }

    func refreshConnected() {
        if host.calendarConnected() { progress.connected.insert(.calendar) }
        if host.hooksInstalled() { progress.connected.insert(.claudeCode) }
        save()
    }

    // MARK: first-week tips

    func tip(_ t: FirstTip) -> String? {
        guard progress.shouldShow(t, now: Date()) else { return nil }
        progress.tipsShown.insert(t)
        save()
        return t.text
    }

    func tipsOff() { progress.tipsOff = true; save() }

    // MARK: plumbing

    private func save() {
        if let d = try? JSONEncoder().encode(progress) { defaults.set(d, forKey: "onboarding") }
        objectWillChange.send()
    }

    func reposition() { panel.position(above: host.anchor()) }

    /// Debug: forget onboarding so it runs again on next launch.
    func reset() {
        progress = OnboardingProgress(firstLaunch: Date())
        save()
    }
}

/// A non-activating card above Hush; the journey's words live here.
@MainActor
final class OnboardingPanel {
    private var card: CardWindow?
    var onRelayout: (() -> Void)?
    static let width: CGFloat = 400
    private var anchor: NSRect = .zero

    var isOpen: Bool { card?.isOpen ?? false }

    func show<V: View>(view: V) {
        let c = card ?? CardWindow(width: Self.width, maxHeight: 640) { view }
        card = c
        c.show(avoiding: anchor)
    }

    func position(above anchor: NSRect) {
        self.anchor = anchor
        DispatchQueue.main.async { self.card?.relayout(avoiding: anchor) }
    }

    func close() { card?.close() }
}
