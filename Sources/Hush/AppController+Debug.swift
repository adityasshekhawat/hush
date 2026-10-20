import AppKit
import HushCore
import HushMac
import SwiftUI

/// Opt-in debug hooks (dev.hush.debug) and the Developer menu simulations.
extension AppController {
    func installDebugHooks() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("dev.hush.debug"), object: nil, queue: .main
        ) { [weak self] n in
            let cmd = n.object as? String ?? ""
            MainActor.assumeIsolated { self?.runDebug(cmd) }
        }
        NSLog("Hush debug hooks on")
    }

    func runDebug(_ cmd: String) {
        let parts = cmd.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first ?? "", parts.count > 1 ? parts[1] : "") {
        case ("mail", "ordinary"): simulate(.ordinary)
        case ("mail", "ask"): simulate(.ask)
        case ("mail", "vip"): simulate(.vip)
        case ("mail", "bulk"): simulate(.bulk)
        case ("meeting", let m): simulateMeeting(inMinutes: Double(m) ?? 10)
        case ("pose", "live"): previewAway = false; previewOverride = nil
        case ("pose", "away"): previewAway = true; previewOverride = .hide
        case ("pose", let p): previewOverride = CharacterState(rawValue: p)
        case ("shoo", _): handle(.shoo)
        case ("click", _): handle(.click)
        case ("react", "hover"): renderer.react(.hover(true))
        case ("react", "unhover"): renderer.react(.hover(false))
        case ("react", "poke"): renderer.react(.poke)
        case ("react", "pat"): renderer.react(.pat(true))
        case ("react", "unpat"): renderer.react(.pat(false))
        case ("react", "lift"): handle(.dragBegan)
        case ("react", "swing"): renderer.react(.swing(1200))
        case ("react", "drop"): handle(.dragEnded)
        case ("calm", let m): renderer.react(.debugCalm(m))
        case ("body", "restore"): renderer.apply(look)
        case ("body", let b):
            // Preview only; the saved look is untouched.
            var l = look
            l.body = b
            renderer.apply(l)
        case ("wear", let spec):
            // Preview only: wear:head=wizard,neck=cape,carry=laptop,palette=berry,body=square
            var l = look
            for pair in spec.split(separator: ",") {
                let kv = pair.split(separator: "=").map(String.init)
                guard kv.count == 2 else { continue }
                switch kv[0] {
                case "palette": l.palette = kv[1]
                case "body": l.body = kv[1]
                case "topper": l.topper = kv[1]
                default: if WearSlot(rawValue: kv[0]) != nil { l.outfit[kv[0]] = kv[1] == "none" ? nil : kv[1] }
                }
            }
            renderer.apply(l)
        case ("agent", let spec):
            // agent:<kind>[:<session>] e.g. agent:prompt:s1, agent:stop:s1 (pretends the run started 5 min ago)
            let parts = spec.split(separator: ":").map(String.init)
            if let kind = AgentSessionEvent.Kind(rawValue: parts[0]) {
                let sid = parts.count > 1 ? parts[1] : "debug-session-1"
                let at = kind == .prompt && parts.count > 2 && parts[2] == "old" ? Date().addingTimeInterval(-300) : Date()
                // A host app that isn't frontmost, so the run counts as "in the background" (iTerm if installed).
                agentEvent(AgentSessionEvent(sessionID: sid, cwd: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/hush").path, kind: kind,
                                             app: "com.googlecode.iterm2", at: at))
            }
        case ("seq", let spec):
            // seq:<name>[|key=value,...] plays a designer sequence (v1 art), e.g. seq:agentDone|flag=hush
            let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
            renderer.react(.sequence(parts[0], Self.labels(parts.count > 1 ? parts[1] : "")))
        case ("variant", let spec):
            // variant:<NN-state>|<variant>[|key=value,...] shows a state's variant, e.g. variant:11-notice|careful|card=Look carefully
            let parts = spec.split(separator: "|", maxSplits: 2).map(String.init)
            if let st = CharacterState(rawValue: parts[0]) {
                renderer.show(st, fromEdge: false, duck: false, variant: parts.count > 1 ? parts[1] : nil,
                              labels: Self.labels(parts.count > 2 ? parts[2] : ""))
            }
        case ("flag", let n):
            // flag:<i> clicks the i-th flag on the rail (0: nearest Hush).
            let flags = FlagRail.layout(waiting: waiting).flags
            if let i = Int(n), flags.indices.contains(i) { openFlag(flags[i].decisionID) }
        case ("command", "open"): toggleCommandBox()
        case ("digest", "now"): digest.showNow()
        case ("digest", "away"):
            // Pretend you were away for the last 3 hours and just came back (needs the digest switched on).
            digest.focusChanged(away: true, now: Date().addingTimeInterval(-3 * 3600))
            digest.focusChanged(away: false)
        case ("login", let v): LoginItem.set(v == "on")
        case ("onboard", "reset"): onboarding.reset()
        case ("onboard", "start"): onboarding.start(from: .arrival)
        case ("onboard", "next"): onboarding.next()
        case ("onboard", "persona"): onboarding.togglePersona(.builder)
        case ("onboard", "hi"): ["hover", "pat"].forEach { onboarding.observed($0) }
        case ("ask", let q):
            // Same routing as the box, from the app that's frontmost now.
            let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            // Same path as the command box, including the smarter router's check when the rules aren't sure.
            let route = AskRouter.route(q, context: ask.context(frontmostApp: app))
            ask.submit(route.text, lane: route.lane, frontmostApp: app, followUp: nil, check: !route.confident && !route.explicit)
        case ("askfrom", let spec):
            // askfrom:<bundle id>|<question>: route and answer as if asked from that app.
            let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let route = AskRouter.route(parts[1], context: ask.context(frontmostApp: parts[0]))
                ask.ask(route.text, lane: route.lane, frontmostApp: parts[0])
            }
        case ("box", let text):
            // Preview the command box with typed text (scripted opens can't take focus, so keep it open).
            commandPanel.keepOpenForPreview = true
            if !commandPanel.isOpen { toggleCommandBox(); commandPanel.keepOpenForPreview = true }
            commandPanel.model.text = text == "-" ? "" : text
        case ("boxtab", _): commandPanel.model.tab()
        case ("pause", let l): pause(PauseLength(rawValue: l) ?? .hour)
        case ("resume", _): resume()
        case ("saver", let v):
            // saver:on|off: act as if Low Power Mode were on, for measuring (ADR-022).
            defaults.set(v == "on", forKey: "HushForceSaver")
            applyEnergy()
        case ("pouch", let v):
            // pouch:simpler|shorter|bullets: pick a verb as if from the chips (needs full cheeks and consent).
            if let verb = PouchVerb(rawValue: v) { pouch.debugPick(verb) }
        case ("handoffpreview", let q):
            // Shows the hand-off receipt without opening anything.
            ask.card.model.question = q
            ask.card.model.lane = .handoff(.chatgpt)
            ask.card.model.context = "from a web browser"
            ask.card.model.phase = .handedOff(.chatgpt)
            ask.card.show(above: cardAvoidRect())
            renderer.react(.wave)
        case ("boxclose", _): commandPanel.close(restoreFocus: false)
        case ("askstop", _): ask.stop()
        case ("envelope", "close"): envelope.close()
        case ("rules", "show"): showRules()
        case ("panel", _): openPanel?()
        case ("appearance", let v): NSApp.appearance = v == "light" ? NSAppearance(named: .aqua) : v == "dark" ? NSAppearance(named: .darkAqua) : nil
        case ("session", "first"): if let id = ask.card.model.sessions.first?.id { ask.selectSession(id) }
        case ("calendar", "request"):
            Task { let ok = await requestCalendarAccess(); DiagnosticsLog.write("calendar: request returned \(ok)") }
        case ("history", _): ask.showHistory()
        case ("journal", _): journal.show()
        case ("record", let spec):
            // record:start:<name> … record:stop → ~/Library/Application Support/Hush/recordings/<name>.gif (README media)
            let parts = spec.split(separator: ":").map(String.init)
            if parts.first == "start", parts.count == 2 {
                recorder.start(name: parts[1], around: panel.frame, screen: screen?.frame ?? panel.frame)
            } else if parts.first == "stop" {
                recorder.stop()
            }
        case ("look", "brand"):
            // Recordings: the brand look (lilac blob with a leaf, nothing worn). Your look is kept and restored after.
            if defaults.data(forKey: "lookBeforeRecording") == nil, let d = try? JSONEncoder().encode(look) {
                defaults.set(d, forKey: "lookBeforeRecording")
            }
            rare?.suppressed = true
            setLook { l in l = CharacterLook(); l.palette = "lilac" }
        case ("look", "restore"):
            if let d = defaults.data(forKey: "lookBeforeRecording"), let saved = try? JSONDecoder().decode(CharacterLook.self, from: d) {
                setLook { $0 = saved }
                defaults.removeObject(forKey: "lookBeforeRecording")
            }
            rare?.suppressed = false
        case ("svgdump", _):
            // The character exactly as a recording frame sees it (for checking what's drawn).
            Task { @MainActor in
                guard let snap = await (renderer as? WebCharacterRenderer)?.snapshotSVG() else { return }
                let url = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/Hush/recordings/snapshot.svg")
                try? snap.svg.write(to: url, atomically: true, encoding: .utf8)
                DiagnosticsLog.write("record: svg dumped")
            }
        case ("dismiss", _):
            // Put everything away without teaching Hush anything (a shoo would lower that kind of item).
            envelope.close()
            while active != nil { resolveActive(.ignored) }
            previewOverride = nil
        case ("cleandemo", _):
            Task {
                let n = (try? await engine.forgetDemoData()) ?? 0
                DiagnosticsLog.write("debug: removed \(n) simulated item(s) from the log")
            }
        case ("focus", let spec):
            // focus:<bundle id>|<tty>: what "Open" on an agent card does.
            let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
            SessionInput.focus(bundleID: parts.first, tty: parts.count > 1 ? parts[1] : nil)
        case ("bubbles", _):
            // Put away any speech bubble (between recordings).
            bubble.hide()
            tipBubble.hide()
        case ("pile", let n):
            // pile:0 clears the held-mail stack beside Hush without opening Mail (recordings).
            ambientPile = Int(n) ?? 0
            refresh()
        case ("pouchopen", _):
            // Opens the verb card as a click on full cheeks would (for recordings).
            if !antics.cheeksFull { antics.refillCheeks() }
            _ = pouch.clicked()
        case ("maildigest", _):
            // The digest now, as if at a natural break (ignores the hourly limit).
            defaults.removeObject(forKey: "lastMailDigest")
            maybeMailDigest()
        case ("wardrobe", _): openWardrobe?()
        case ("settings", let s): openSettings?(SettingsSection.allCases.first { $0.rawValue.lowercased().hasPrefix(s) } ?? .general)
        case ("rare", let id): rare.debugFind(id)
        case ("held", "day"): showHeldBack(.day)
        case ("held", "week"): showHeldBack(.week)
        case ("browser", let v): ask.browserTasks = v == "on"
        case ("approve", _): ask.browser.approve()
        case ("answer", let v): ask.browser.answer(v == "yes")
        case ("followup", let q):
            if let f = ask.followUpSource { ask.ask(q, lane: f.lane, frontmostApp: nil, followUp: f) }
        case ("askrepo", let path):
            if !ask.allowedRepos.contains(path) { ask.allowedRepos = ask.allowedRepos + [path] }
            ask.pickedRepo = path
        case ("hooks", "install"): HookInstaller.install()
        case ("move", "perch"): wanderer.debugPerch()
        case ("move", "leave"): wanderer.leavePerch()
        case ("move", "drop-on-front"):
            // Simulates a slightly-off drop: floor line 12 pt above the front window's top edge.
            if let w = Wanderer.focusedWindow() {
                handle(.dragBegan)
                let r = Wanderer.screenRect(w.bounds)
                var f = panel.frame
                f.origin.x = r.midX - f.width / 2
                f.origin.y = r.maxY - renderer.characterHeight * 146 / 100 * 34 / 146 + 12
                panel.setFrame(f, display: true)
                handle(.dragEnded)
            }
        case ("move", "walk"): setHome(homeX < 0.5 ? 0.92 : 0.04)
        case ("mood", let n): renderer.react(.mood(Int(n) ?? 0))
        case ("play", "inbox"): renderer.react(.inboxZero)
        case ("play", "command"): playCommandWindow()
        case ("antic", "copy"): antics.debugEvent(.copied)
        case ("antic", "blow"): renderer.react(.blow)
        case ("antic", "paste"): antics.debugEvent(.pasted)
        case ("antic", "ask"): antics.debugAsk()
        case ("antic", "touch"): antics.touched()
        case ("antic", "shot"): antics.debugEvent(.screenshot)
        case ("antic", "shake"): renderer.react(.woozy)
        case ("antic", "flinch"): antics.debugEvent(.windowPassing(dx: 40))
        case ("antic", "perk"): antics.debugEvent(.chargerPlugged)
        case ("antic", "morning"): renderer.react(.morning)
        case ("antic", "dance"): renderer.react(.dance)
        case ("antic", "tuck"): antics.tuckIn()
        case ("antic", "groove"): antics.debugEvent(.audioPlaying(true))
        case ("antic", "ungroove"): antics.debugEvent(.audioPlaying(false))
        case ("antic", "droopy"): antics.debugEvent(.batteryLow(true))
        case ("antic", "undroopy"): antics.debugEvent(.batteryLow(false))
        case ("resolve", _): resolveActive(.opened)
        default: break
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            NSLog("Hush state=%@ waiting=%d pile=%d", self.currentState?.rawValue ?? "nil", self.waiting.count, self.ambientPile)
        }
    }

    // MARK: calendar

    enum DemoMail { case ordinary, ask, vip, bulk }

    func simulate(_ kind: DemoMail) {
        let id = "demo:" + UUID().uuidString
        let item: InboxItem
        switch kind {
        case .ordinary:
            item = InboxItem(id: id, kind: .mail, senderName: "Sam Rivera", senderAddress: "sam@example.com",
                             subject: "Photos from Saturday", snippet: "Uploaded the album", receivedAt: Date())
        case .ask:
            item = InboxItem(id: id, kind: .mail, senderName: "Priya Nair", senderAddress: "priya@example.com",
                             subject: "Can you review the Q4 plan by EOD?", snippet: "Two sections need your call",
                             receivedAt: Date())
        case .vip:
            // Engine-only, never saved: the demo address shouldn't end up in the user's real VIP list.
            // One Task so the VIP is in place before the item is evaluated.
            var demo = settings
            demo.vips.insert(Self.demoVIP)
            let vipItem = InboxItem(id: id, kind: .mail, senderName: "Demo VIP", senderAddress: Self.demoVIP,
                                    subject: "Quick call?", snippet: "Need five minutes before the board meeting",
                                    receivedAt: Date())
            Task { [demo] in
                await engine.update(settings: demo)
                do {
                    guard let d = try await engine.evaluate(vipItem) else { return }
                    await handle(d)
                } catch {
                    DiagnosticsLog.write("debug: VIP demo failed: \(error.localizedDescription)")
                }
            }
            return
        case .bulk:
            item = InboxItem(id: id, kind: .mail, senderName: "Shop", senderAddress: "deals@shop.example",
                             subject: "48 hours only", headers: ["List-Unsubscribe": "<mailto:u@shop.example>"],
                             receivedAt: Date())
        }
        submit(item)
    }

    func simulateMeeting(inMinutes m: Double) {
        let start = Date().addingTimeInterval(m * 60)
        // A demo call link (example.zoom.us doesn't exist, so "joining" opens a harmless page) and notes for the context line.
        demoMeetings.append(Meeting(id: "demo-" + UUID().uuidString, title: "Q4 roadmap (demo)", start: start,
                                    end: start.addingTimeInterval(30 * 60), attendees: ["Priya Nair", "Sam Rivera", "Dana Lee", "Lee Park"],
                                    joinURL: URL(string: "https://example.zoom.us/j/123456789"),
                                    notes: "Walk through the Q4 roadmap. Bring the hiring plan and last quarter's numbers."))
        planReminders()
    }

    /// The held-back ledger at the top of the menu.
    var summaryLines: (today: String, week: String) {
        get async {
            let d = try? await engine.daySummary(), w = try? await engine.weekSummary()
            return (d.map { "Today: \($0.shown) shown · \($0.heldBack) held back" } ?? "Today: no data",
                    w.map { "This week: \($0.shown) shown · \($0.heldBack) held back" } ?? "This week: no data")
        }
    }

    /// "flag=hush,bin=3" → ["flag": "hush", "bin": "3"]
    static func labels(_ spec: String) -> [String: String] {
        Dictionary(spec.split(separator: ",").compactMap { kv -> (String, String)? in
            let p = kv.split(separator: "=", maxSplits: 1).map(String.init)
            return p.count == 2 ? (p[0], p[1]) : nil
        }, uniquingKeysWith: { $1 })
    }
}
