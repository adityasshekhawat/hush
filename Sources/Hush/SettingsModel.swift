import AppKit
import HushCore
import HushMac
import SwiftUI

/// One view of every setting, shared by the menu bar panel and the Settings window (docs/design-guide.md §5.10).
/// It reads and writes through AppController's own setters, so nothing is stored twice.
@MainActor
final class SettingsModel: ObservableObject {
    let app: AppController
    init(app: AppController) { self.app = app }

    /// Re-read everything (call when a view appears or after a change made elsewhere).
    func reload() { objectWillChange.send() }

    private func set(_ change: () -> Void) {
        change()
        objectWillChange.send()
        app.onRefresh?()
    }

    func binding<T>(_ get: @escaping () -> T, _ put: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: get, set: { v in self.set { put(v) } })
    }

    // MARK: general

    var interruptsPerDay: Binding<Int> {
        binding({ self.app.settings.maxInterruptsPerDay }, { n in self.app.setSettings { $0.maxInterruptsPerDay = n } })
    }
    var quietHours: Binding<Bool> {
        binding({ self.app.settings.quietHours != nil },
                { on in self.app.setSettings { $0.quietHours = on ? QuietHours(start: (22, 0), end: (7, 0)) : nil } })
    }
    var openAtLogin: Binding<Bool> { binding({ LoginItem.isOn }, { LoginItem.set($0) }) }
    var hideInFullScreen: Binding<Bool> { binding({ self.app.hidesInFullScreen }, { self.app.hidesInFullScreen = $0 }) }
    var hiddenFromCapture: Binding<Bool> { binding({ self.app.hiddenFromCapture }, { self.app.hiddenFromCapture = $0 }) }
    var showCount: Binding<Bool> {
        binding({ self.app.defaults.bool(forKey: "menuBarCount") }, { self.app.defaults.set($0, forKey: "menuBarCount") })
    }

    // MARK: character

    var look: CharacterLook { app.look }
    func setLook(_ change: @escaping (inout CharacterLook) -> Void) { set { app.setLook(change) } }
    func wear(_ slot: WearSlot) -> Binding<String> {
        binding({ self.app.look.outfit[slot.rawValue] ?? "none" },
                { v in self.app.setLook { $0.outfit[slot.rawValue] = v == "none" ? nil : v } })
    }

    // MARK: home, perch, moods

    var homeX: Binding<Double> { binding({ Double(self.app.homeX) }, { self.app.setHome(CGFloat($0)) }) }
    var perch: Binding<Bool> { binding({ self.app.perchEnabled }, { self.app.perchEnabled = $0 }) }
    var moods: Binding<Bool> { binding({ self.app.moodsEnabled }, { self.app.moodsEnabled = $0 }) }

    // MARK: Ask Hush

    var pouch: Binding<Bool> { binding({ self.app.pouch.enabled }, { self.app.pouch.enabled = $0 }) }
    var smartRouting: Binding<Bool> { binding({ self.app.ask.smartRouting }, { self.app.ask.smartRouting = $0 }) }
    var learnedCount: Int { app.ask.learnedRoutes.entries.count }
    func forgetLearnedRoutes() { set { app.ask.learnedRoutes = LearnedRoutes() } }

    var handoff: Binding<AskLane.Provider> { binding({ self.app.ask.preferredHandoff }, { self.app.ask.preferredHandoff = $0 }) }
    func model(_ lane: LaneID) -> Binding<String> {
        binding({ LaneSettings.spec(lane).model },
                { m in LaneSettings.setModel(m == LaneRegistry.defaultSpec(lane).model ? nil : m, for: lane) })
    }
    var repos: [String] { app.ask.allowedRepos }
    func addRepo() { set { app.ask.addRepo() } }
    func removeRepo(_ p: String) { set { app.ask.removeRepo(p) } }
    var digestOn: Bool { app.digest.enabled }
    func toggleDigest() { set { app.digest.toggleWithConsent() } }

    // MARK: browser tasks

    var browserTasks: Binding<Bool> { binding({ self.app.ask.browserTasks }, { self.app.ask.browserTasks = $0 }) }
    var taskBrowser: Binding<String> {
        binding({ self.app.ask.browser.preferredBrowser?.rawValue ?? "auto" },
                { self.app.ask.browser.preferredBrowser = TaskBrowser(rawValue: $0) })
    }
    var browsersWithExtension: [TaskBrowser] { TaskBrowser.allCases.filter(TaskBrowsers.withExtension().contains) }

    // MARK: connections

    enum Connection: String, CaseIterable, Identifiable {
        case calendar, claude, codex, mail, appleIntelligence
        var id: String { rawValue }
    }

    var connections: [Connection] { Connection.allCases.filter { $0 != .codex || HookInstaller.codexPresent } }

    func title(_ c: Connection) -> String {
        switch c {
        case .calendar: "Calendar"
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .mail: "Mail"
        case .appleIntelligence: "Apple Intelligence"
        }
    }

    func symbol(_ c: Connection) -> String {
        switch c {
        case .calendar: "calendar"
        case .claude, .codex: "terminal"
        case .mail: "envelope"
        case .appleIntelligence: "sparkles"
        }
    }

    /// nil = not connected (offer Connect).
    func status(_ c: Connection) -> String? {
        switch c {
        case .calendar: CalendarSource.access == .granted ? "Connected" : nil
        case .claude: HookInstaller.isInstalled ? "Watching" : nil
        case .codex: HookInstaller.isInstalled(.codex) ? "Watching" : nil
        case .mail: "Waiting on MailKit"
        case .appleIntelligence: onDeviceOn && OnDeviceTriage.systemStatus == .on ? "On this Mac" : nil
        }
    }

    /// The on-device model judges mail (your switch; Apple Intelligence itself is a System Settings switch).
    var onDeviceOn: Bool { UserDefaults.standard.object(forKey: "useOnDeviceModel") as? Bool ?? true }

    func setOnDevice(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "useOnDeviceModel")
        Task { await app.triage.setEnabled(on); if on { await app.triage.prewarm() } }
        reload()
    }

    /// Why a connection can't be turned on from here, in plain words (shown instead of a button).
    func note(_ c: Connection) -> String? {
        guard c == .appleIntelligence, onDeviceOn else { return nil }
        switch OnDeviceTriage.systemStatus {
        case .appleIntelligenceOff: return "Off in System Settings"
        case .notReady: return "Getting ready"
        case .unsupported: return "Not available on this Mac"
        case .on, .turnedOff: return nil
        }
    }

    /// Hooks from an older Hush (ADR-024).
    func needsUpdate(_ c: Connection) -> Bool {
        switch c {
        case .claude: HookInstaller.needsUpdate(.claude)
        case .codex: HookInstaller.needsUpdate(.codex)
        default: false
        }
    }

    func connectTitle(_ c: Connection) -> String { c == .appleIntelligence ? "Turn on" : "Connect" }

    func connect(_ c: Connection) {
        switch c {
        case .calendar:
            if CalendarSource.access == .denied {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            } else { Task { _ = await app.requestCalendarAccess(); reload() } }
        case .claude: HookInstaller.install(); reload()
        case .codex: HookInstaller.install(.codex); reload()
        case .mail: break
        case .appleIntelligence:
            if OnDeviceTriage.systemStatus == .appleIntelligenceOff {
                let pane = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!
                if !NSWorkspace.shared.open(pane) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
                }
            } else { setOnDevice(true) }
        }
    }

    func disconnect(_ c: Connection) {
        switch c {
        case .claude: HookInstaller.uninstall(); reload()
        case .codex: HookInstaller.uninstall(.codex); reload()
        case .appleIntelligence: setOnDevice(false)
        default: break
        }
    }

    // MARK: setup

    var setupLeft: [ConnectStep] { app.onboarding.progress.remaining(claudeInstalled: app.onboarding.claudeInstalled) }
    func doSetup(_ step: ConnectStep) {
        switch step {
        case .calendar: connect(.calendar)
        case .claudeCode: connect(.claude)
        case .askHotkey: app.toggleCommandBox()
        }
    }
    func setupTitle(_ step: ConnectStep) -> String {
        switch step {
        case .calendar: "Connect Calendar"
        case .claudeCode: "Watch my Claude Code sessions"
        case .askHotkey: "Try ⌘⇧H to ask me anything"
        }
    }
    func replayIntro() { app.onboarding.start(from: .arrival) }
    var tipsOff: Bool { app.onboarding.progress.tipsOff }
    func turnOffTips() { set { app.onboarding.tipsOff() } }

    // MARK: status (panel header)

    var statusWord: String {
        if app.waiting.count > 0 { return app.waiting.count == 1 ? "Holding 1 thing" : "Holding \(app.waiting.count) things" }
        if let until = app.pausedUntil { return PauseText.status(until: until, now: Date()) }
        if app.focus.state.hidesCharacter { return "In focus" }
        if app.settings.quietHours?.contains(Date(), calendar: .current) == true { return "Asleep" }
        if agentWorking { return "Claude is working" }
        return "Quiet"
    }

    var agentWorking: Bool {
        app.agentSessions.workingInBackground(now: Date(), frontmostApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }
}
