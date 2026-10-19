import AppKit
import HushCore
import HushMac

/// Ask Hush v2 (docs/ask-design.md): a typed question takes one of three lanes.
/// - quick: one fast model call with a JSON schema → a card shaped to the answer
/// - repo: read-only Claude Code run in an allowed repo → streaming card
/// - hand-off: opens ChatGPT / Claude / Perplexity with the question pre-filled
/// One task at a time; a new question replaces a running one. Everything is logged locally (AgentTask).
@MainActor
final class AskController {
    struct Host {
        var engine: DecisionEngine
        var react: (Reaction) -> Void
        var anchor: () -> NSRect
        var refresh: () -> Void
        var submit: (InboxItem) -> Void
        var recentSessionCwd: () -> String?
        /// A question was answered (counts toward the monocle).
        var asked: () -> Void = {}
        /// The sessions lane: live hook state, whether transcripts may be read, Open and Summarise.
        var liveSessions: () -> [String: AgentSessionTracker.Session] = { [:] }
        var transcriptsAllowed: () -> Bool = { false }
        var openApp: (String?) -> Void = { _ in }
        var summarise: (SessionDigest) -> Void = { _ in }
        /// Watching a session for its finish (AgentSessionTracker.watch).
        var watched: () -> Set<String> = { [] }
        var setWatch: (String, Bool) -> Void = { _, _ in }
    }

    let host: Host
    let card = AnswerCard()
    let history = HistoryWindowController()
    /// Browser tasks share the card (docs/lanes-plan.md § L3).
    private(set) var browser: BrowserTaskController!
    private let defaults = UserDefaults.standard
    private var runner: ClaudeCodeRunner?
    private var task: AgentTask?
    private(set) var isRunning = false
    /// The question on the card (for "Continue in…") and the app you asked from (for the action row).
    private var currentQuestion: String?
    /// The smarter router's model check, while it runs.
    private var routeRunner: ClaudeCodeRunner?
    /// Turns before the current one, when it was a follow-up.
    private var thread: [FollowUp.Turn] = []
    /// Opens the command box in follow-up mode (wired by AppController).
    var openFollowUp: (() -> Void)?
    private var currentApp: String?
    /// App router targets installed on this Mac (checked once; reinstalling an app needs a relaunch to show up).
    private lazy var installedTargets: Set<String> = Set(AppTarget.allCases.compactMap(\.bundleID)
        .filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil })

    init(host: Host) {
        self.host = host
        card.onStop = { [weak self] in self?.stop() }
        card.onContinue = { [weak self] p in self?.continueIn(p) }
        card.onAction = { [weak self] a in self?.perform(a) }
        card.continueProvider = preferredHandoff
        browser = BrowserTaskController(host: .init(
            card: card, react: host.react, anchor: host.anchor, refresh: host.refresh, submit: host.submit,
            save: { [weak self] t in self?.save(t) }))
        card.onApprove = { [weak self] in self?.browser.approve() }
        card.onPrompt = { [weak self] ok in self?.browser.answer(ok) }
        card.onFollowUp = { [weak self] in self?.openFollowUp?() }
        card.onRetry = { [weak self] in self?.retry() }
        card.onOpenSession = { [weak self] l in self?.openSession(l) }
        card.onSummariseSession = { [weak self] l in self?.summariseSession(l) }
        card.onSelectSession = { [weak self] id in self?.selectSession(id) }
        card.onToggleWatch = { [weak self] l in self?.toggleWatch(l) }
        card.onCompose = { [weak self] l in self?.compose(l) }
        card.onClose = { [weak self] in self?.browser.cardClosed(); self?.stopLiveView() }
        card.canFollowUp = { [weak self] in self?.followUpSource != nil }
    }

    // MARK: settings

    var preferredHandoff: AskLane.Provider {
        get { defaults.string(forKey: "preferredHandoff").flatMap(AskLane.Provider.init(rawValue:)) ?? .chatgpt }
        set { defaults.set(newValue.rawValue, forKey: "preferredHandoff"); card.continueProvider = newValue }
    }

    /// Agent ▸ Browser tasks: off until you turn it on.
    var browserTasks: Bool {
        get { defaults.bool(forKey: "browserTasks") }
        set { defaults.set(newValue, forKey: "browserTasks"); DiagnosticsLog.write("browser: tasks \(newValue ? "on" : "off")") }
    }

    var allowedRepos: [String] {
        get { defaults.stringArray(forKey: "agentRepos") ?? [] }
        set { defaults.set(Array(NSOrderedSet(array: newValue)) as? [String] ?? newValue, forKey: "agentRepos") }
    }
    var pickedRepo: String?
    private var lastUsedRepo: String? {
        get { defaults.string(forKey: "agentLastRepo") }
        set { defaults.set(newValue, forKey: "agentLastRepo") }
    }

    var currentRepo: String? {
        RepoChooser.choose(picked: pickedRepo, recentSessionCwd: host.recentSessionCwd(), lastUsed: lastUsedRepo, allowed: allowedRepos)
    }

    /// What the router needs to know, given the app you were in when you opened the box.
    func context(frontmostApp: String?) -> AskContext {
        AskContext(frontmostApp: frontmostApp, repos: allowedRepos, defaultRepo: currentRepo, preferredHandoff: preferredHandoff,
                   browserTasks: browserTasks)
    }

    @discardableResult
    func addRepo() -> String? {
        let open = NSOpenPanel()
        open.canChooseDirectories = true
        open.canChooseFiles = false
        open.allowsMultipleSelection = false
        open.message = "Choose a repository Hush's agent may read. Its code is sent to Claude only when you ask about it."
        open.prompt = "Allow"
        open.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Developer")
        NSApp.activate()
        open.level = .modalPanel
        guard open.runModal() == .OK, let url = open.url else { return nil }
        allowedRepos = allowedRepos + [url.path]
        pickedRepo = url.path
        DiagnosticsLog.write("ask: allowed repo \(url.lastPathComponent)")
        return url.path
    }

    func removeRepo(_ path: String) {
        allowedRepos = allowedRepos.filter { $0 != path }
        if pickedRepo == path { pickedRepo = nil }
    }

    // MARK: asking

    /// The thread a follow-up would build on: earlier turns plus the finished answer on the card.
    var followUpSource: FollowUp? {
        guard card.isOpen, card.model.phase == .done, let q = currentQuestion else { return nil }
        if case .handoff = card.model.lane { return nil }
        let answer = card.model.copyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return nil }
        return FollowUp(turns: thread, lane: card.model.lane).adding(.init(question: q, answer: answer))
    }

    /// Smart routing (on by default): when the rules aren't sure, a quick model picks the lane on Return.
    var smartRouting: Bool {
        get { defaults.object(forKey: "smartRouting") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "smartRouting") }
    }

    /// Your corrections, kept on this Mac.
    var learnedRoutes: LearnedRoutes {
        get { defaults.data(forKey: "learnedRoutes").flatMap { try? JSONDecoder().decode(LearnedRoutes.self, from: $0) } ?? LearnedRoutes() }
        set { if let d = try? JSONEncoder().encode(newValue) { defaults.set(d, forKey: "learnedRoutes") } }
    }

    func learnCorrection(_ text: String, lane: LaneKind) {
        var l = learnedRoutes
        l.record(text, lane: lane)
        learnedRoutes = l
        DiagnosticsLog.write("route: learned \(lane.rawValue) (\(l.entries.count) kept)")
    }

    /// Submit from the command box: straight to the lane, or a quick model check first when nobody's sure.
    func submit(_ question: String, lane: AskLane, frontmostApp: String?, followUp: FollowUp?, check: Bool) {
        guard check, smartRouting, ClaudeCodeRunner.locateClaude() != nil else {
            ask(question, lane: lane, frontmostApp: frontmostApp, followUp: followUp)
            return
        }
        stop(silently: true)
        let m = card.model
        m.question = question
        m.lane = lane
        m.shape = nil
        m.text = ""
        m.actions = []
        m.receipt = nil
        m.isSessionsReport = false
        m.context = nil
        m.phase = .working
        m.activity = "Choosing a route…"
        card.show(above: host.anchor())
        let ctx = context(frontmostApp: frontmostApp)
        let running = host.liveSessions().values.filter { $0.workingSince != nil || $0.waitingForYou }.count
        var o = ClaudeCodeRunner.Options(cwd: FileManager.default.temporaryDirectory, prompt: question, allowedTools: [])
        o.apply(LaneSettings.spec(.route))
        o.systemPrompt = RouteCheck.systemPrompt(context: ctx, runningSessions: running)
        o.jsonSchema = RouteCheck.jsonSchema(context: ctx)
        let r = ClaudeCodeRunner(options: o)
        routeRunner = r
        let started = Date()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let box = PickBox()
            r.run { event in if case .structured(let d) = event { box.set(d) } }
            let data = box.data
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.routeRunner === r else { return }
                    self.routeRunner = nil
                    let ms = Int(Date().timeIntervalSince(started) * 1000)
                    if let data, let choice = RouteCheck.parse(data, question: question, context: ctx) {
                        DiagnosticsLog.write("route: model picked \(LaneKind(choice.lane).rawValue) in \(ms) ms (rules had \(LaneKind(lane).rawValue))")
                        self.ask(question, lane: choice.lane, frontmostApp: frontmostApp, followUp: followUp)
                        self.card.model.context = choice.why.isEmpty ? "picked for you" : choice.why
                    } else {
                        DiagnosticsLog.write("route: model check failed after \(ms) ms; using the rules")
                        self.ask(question, lane: lane, frontmostApp: frontmostApp, followUp: followUp)
                    }
                }
            }
        }
    }

    func ask(_ question: String, lane: AskLane, frontmostApp: String?, followUp: FollowUp? = nil) {
        routeRunner?.cancel()
        routeRunner = nil
        stop(silently: true)
        stopLiveView()
        thread = followUp?.turns ?? []
        // What the model sees: the question, with the earlier turns when it's a follow-up.
        let prompt = followUp.map { $0.prompt(question) } ?? question
        let ctx = context(frontmostApp: frontmostApp)
        currentQuestion = question
        currentApp = frontmostApp
        let m = card.model
        m.actions = []
        m.receipt = nil
        m.question = question
        m.lane = lane
        m.shape = nil
        m.text = ""
        m.footer = ""
        m.toolCounts = []
        m.sessions = []
        m.isSessionsReport = false
        m.selectedSession = nil
        m.sessionTurns = []
        m.composeText = ""
        m.sessionReceipt = nil
        m.sessionSummaries = [:]
        m.summarising = []
        m.turns = 0
        m.currentStep = nil
        m.okCount = 0
        m.resultURL = nil
        m.copied = false
        m.plan = nil
        m.steps = []
        m.prompt = nil
        m.context = followUp != nil ? "follow-up" : ctx.appName.map { "from \($0)" }

        switch lane {
        case .handoff(let p):
            handOff(prompt, to: p, logPrompt: question)
        case .quick:
            m.phase = .working
            m.activity = "Thinking…"
            startRun(question: prompt, repo: nil, appName: ctx.appName)
        case .repo(let path):
            lastUsedRepo = path
            m.phase = .working
            m.activity = "Reading \(URL(fileURLWithPath: path).lastPathComponent)…"
            startRun(question: prompt, repo: path, appName: ctx.appName)
        case .browser:
            browser.start(prompt)
        case .sessions where followUp != nil:
            // "Why is it stuck?" after a sessions report: a quick answer with the report as context.
            m.lane = .quick
            m.phase = .working
            m.activity = "Thinking…"
            startRun(question: prompt, repo: nil, appName: ctx.appName)
        case .sessions:
            answerSessions(question)
        }
        card.show(above: host.anchor())
        host.refresh()
    }

    private func startRun(question: String, repo: String?, appName: String?) {
        let spec = LaneSettings.spec(repo == nil ? .quick : .repo)
        let t = AgentTask(startedAt: Date(), repo: repo ?? "quick", prompt: question, model: spec.model)
        task = t
        save(t)
        let o = repo.map { LaneOptions.repo(question, repo: $0, spec: spec) }
            ?? LaneOptions.quick(question, appName: appName, spec: spec)
        let r = ClaudeCodeRunner(options: o)
        runner = r
        isRunning = true
        DiagnosticsLog.write("ask: \(repo == nil ? "quick" : "repo \(t.repoName)") started (\(question.count) chars)")
        let id = t.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            r.run { event in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.handle(event, taskID: id) } }
            }
        }
    }

    // MARK: hand-off

    private func handOff(_ text: String, to p: AskLane.Provider, logPrompt: String) {
        let claudeApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "claude://x")!) != nil
        guard let url = p.url(for: text, appInstalled: claudeApp) else { return }
        NSWorkspace.shared.open(url)
        card.model.lane = .handoff(p)
        card.model.phase = .handedOff(p)
        host.react(.wave)
        var t = AgentTask(startedAt: Date(), repo: "handoff", prompt: logPrompt, model: p.rawValue)
        t.status = .done
        t.result = "Opened in \(p.displayName)"
        save(t)
        DiagnosticsLog.write("ask: handed off to \(p.displayName)")
        // The hand-off card is a receipt; it steps aside on its own.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, case .handedOff = self.card.model.phase else { return }
            self.card.close()
        }
    }

    /// The sessions lane: read on the Mac, no model call. Live state from the hooks, plus what each session did from
    /// its transcript when the digest is on.
    private func answerSessions(_ question: String) {
        let m = card.model
        m.phase = .working
        m.activity = "Looking at your sessions…"
        let live = host.liveSessions()
        let readTranscripts = host.transcriptsAllowed()
        let start = Date()
        Task {
            let now = Date()
            let digests = readTranscripts
                ? await TranscriptScanner.digests(in: DateInterval(start: now.addingTimeInterval(-SessionsReport.transcriptWindow), end: now))
                : []
            let lines = SessionsReport.lines(live: live, digests: digests, now: now)
            lastDigests = digests
            m.sessions = lines
            m.watched = host.watched()
            m.isSessionsReport = true
            m.sessionsFromTranscripts = readTranscripts
            m.text = SessionsReport.plainText(lines, now: now)
            m.footer = "Read on this Mac" + (readTranscripts ? "" : " · live state only")
            m.phase = .done
            var t = AgentTask(startedAt: start, repo: "sessions", prompt: question, model: "local")
            t.status = .done
            t.result = m.text
            t.durationMS = Int(Date().timeIntervalSince(start) * 1000)
            save(t)
            DiagnosticsLog.write("ask: sessions, \(lines.count) listed (transcripts \(readTranscripts ? "on" : "off"))")
            host.react(.handOver)
            host.refresh()
            followThrough(question, lines: lines)
        }
    }

    /// After the report: a command to Hush ("let me know when it finishes") is carried out, and a question that names
    /// one session ("what's happening in site") opens that session.
    private func followThrough(_ question: String, lines: [SessionLine]) {
        let m = card.model
        let target = HushCommand.target(question, sessions: lines, selected: nil)
        switch HushCommand.parse(question) {
        case .watch?, .unwatch?:
            let on = HushCommand.parse(question) == .watch
            switch target {
            case .one(let id):
                setWatch(id, on, lines: lines)
            case .ambiguous:
                m.sessionReceipt = "Which one? Open a session, then choose Let me know when it finishes."
            case .none:
                m.sessionReceipt = "No sessions to watch right now."
            }
        case nil:
            let t = " " + question.lowercased() + " "
            if case .one(let id) = target, lines.contains(where: { $0.id == id && t.contains($0.project.lowercased()) }) {
                selectSession(id)
            }
        }
    }

    private func setWatch(_ id: String, _ on: Bool, lines: [SessionLine]) {
        host.setWatch(id, on)
        card.model.watched = host.watched()
        let name = lines.first { $0.id == id }?.project ?? "that session"
        card.model.sessionReceipt = on ? "Got it. I'll tell you when \(name) finishes." : "I've stopped watching \(name)."
        host.react(on ? .handOver : .wave)
        DiagnosticsLog.write("sessions: \(on ? "watching" : "stopped watching") \(name)")
    }

    // MARK: one session, live

    private var lastDigests: [SessionDigest] = []
    private var liveTimer: Timer?

    func selectSession(_ id: String?) {
        let m = card.model
        m.selectedSession = id
        m.sessionTurns = []
        m.composeText = ""
        m.sessionReceipt = nil
        m.sendToClaude = false
        stopLiveView()
        guard id != nil else { return }
        refreshLiveView()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLiveView() }
        }
        liveTimer?.tolerance = 0.5
    }

    func stopLiveView() {
        liveTimer?.invalidate()
        liveTimer = nil
    }

    /// While a session is open: its live status from the hooks, and its last turns from the transcript.
    private func refreshLiveView() {
        let m = card.model
        guard let id = m.selectedSession, card.isOpen else { stopLiveView(); return }
        m.sessions = SessionsReport.lines(live: host.liveSessions(), digests: lastDigests, now: Date())
        m.watched = host.watched()
        guard m.sessionsFromTranscripts else { return }
        Task {
            let turns = await TranscriptScanner.recentTurns(sessionID: id)
            if card.model.selectedSession == id, turns != card.model.sessionTurns { card.model.sessionTurns = turns }
        }
    }

    func toggleWatch(_ line: SessionLine) {
        setWatch(line.id, !card.model.watched.contains(line.id), lines: card.model.sessions)
    }

    /// The composer: Tell Hush (a command, or a question about this session) or Send to Claude (its terminal).
    func compose(_ line: SessionLine) {
        let m = card.model
        let text = m.composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if m.sendToClaude {
            guard line.status != .waiting else { return }
            switch SessionInput.send(text, bundleID: line.app, tty: line.tty) {
            case .typed: m.sessionReceipt = "Sent to \(line.agent.shortName) in \(line.project)."
            case .copied(let app): m.sessionReceipt = "Copied. Press ⌘V then Return in \(app)."
            case .failed(let why): m.sessionReceipt = why
            }
            m.composeText = ""
            host.react(.wave)
            var t = AgentTask(startedAt: Date(), repo: "sessions", prompt: "To \(line.project): \(text)", model: "local")
            t.status = .done
            t.result = m.sessionReceipt ?? ""
            save(t)
            return
        }
        switch HushCommand.parse(text) {
        case .watch?: setWatch(line.id, true, lines: m.sessions); m.composeText = ""
        case .unwatch?: setWatch(line.id, false, lines: m.sessions); m.composeText = ""
        case nil:
            // A question about this session: a quick answer with what Hush knows about it as context.
            let turns = m.sessionTurns.suffix(20).map { t -> String in
                switch t.role {
                case .you: return "You: \(t.text)"
                case .agent: return "\(line.agent.shortName): \(t.text)"
                case .tool: return "[\(t.text)]"
                }
            }.joined(separator: "\n")
            let context = SessionsReport.plainText([line], now: Date()) + (turns.isEmpty ? "" : "\n\nRecent conversation:\n" + turns)
            stopLiveView()
            ask(text, lane: .sessions, frontmostApp: currentApp,
                followUp: FollowUp(turns: [.init(question: "What's happening in \(line.project)?", answer: context)], lane: .sessions))
        }
    }

    /// Menu bar panel ▸ Sessions: the report straight away.
    func showSessions() {
        ask("What's happening in my sessions?", lane: .sessions, frontmostApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    func openSession(_ line: SessionLine) { host.openApp(line.app) }

    func summariseSession(_ line: SessionLine) {
        guard let d = line.digest else { return }
        card.model.summarising.insert(line.id)
        host.summarise(d)
    }

    /// "Try again" on a failed card: same question, same lane, same thread.
    func retry() {
        guard let q = currentQuestion else { return }
        let lane = card.model.lane
        ask(q, lane: lane, frontmostApp: currentApp, followUp: thread.isEmpty ? nil : FollowUp(turns: thread, lane: lane))
    }

    /// "Continue in ChatGPT": the question plus Hush's answer, so the conversation picks up where Hush left off.
    func continueIn(_ p: AskLane.Provider) {
        guard let q = currentQuestion else { return }
        let answer = card.model.copyText.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = q
        if !answer.isEmpty, card.model.phase == .done {
            text += "\n\n(A quick answer I already have: \(answer.prefix(1200)))\n\nLet's go further."
        }
        handOff(text, to: p, logPrompt: q)
    }

    // MARK: app router (R0: permission-free rungs only)

    func perform(_ a: AppAction) {
        let text = card.model.copyText
        switch a.mechanism {
        case .copy:
            card.copy()
        case .copyAndActivate(let id):
            card.copy()
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        case .copyAndOpen(let url):
            card.copy()
            NSWorkspace.shared.open(url)
        case .continueIn(let p):
            continueIn(p)
            return
        }
        card.model.receipt = a.receipt
        host.react(.wave)
        var t = AgentTask(startedAt: Date(), repo: "action", prompt: currentQuestion ?? "", model: a.target?.rawValue ?? "copy")
        t.status = .done
        t.result = "\(a.title): \(text.prefix(200))"
        save(t)
        DiagnosticsLog.write("router: \(a.id)")
    }

    func stop(silently: Bool = false) {
        if let r = routeRunner, !silently { r.cancel(); routeRunner = nil; card.model.phase = .cancelled }
        browser.stop(silently: silently)
        guard isRunning, let r = runner else { return }
        runner = nil
        r.cancel()
        if !silently { finish(.cancelled) }
    }

    private func handle(_ e: ClaudeCodeRunner.Event, taskID: String) {
        guard var t = task, t.id == taskID else { return }   // an old run that was replaced
        let m = card.model
        switch e {
        case .started:
            break
        case .denied(let what):
            DiagnosticsLog.write("ask: denied \(what)")
        case .text(let s):
            if t.repo != "quick" { m.text += s }   // quick answers arrive structured, not as prose
        case .tool(let name):
            if !t.toolsUsed.contains(name) { t.toolsUsed.append(name) }
            if name != "StructuredOutput" { m.countTool(name) }
            m.activity = Self.describe(tool: name, repo: t.repoName)
        case .structured(let data):
            if let shape = try? JSONDecoder().decode(AnswerShape.self, from: data) { m.shape = shape }
        case .finished(let result, let cost, let turns, let ms, let context):
            if m.shape == nil && m.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { m.text = result }
            t.result = m.shape?.plainText ?? result
            t.costUSD = cost
            t.durationMS = ms
            t.contextTokens = context
            task = t
            m.turns = turns
            // Model, time and cost stay off the card (History in the menu bar has them).
            m.footer = ""
            finish(.done)
            return
        case .failed(let why):
            t.result = why
            task = t
            finish(.failed(why.count > 140 ? "Something went wrong. Try again, or ask \(preferredHandoff.displayName)." : why))
            return
        case .cancelled:
            finish(.cancelled)
            return
        }
        task = t
    }

    private func finish(_ phase: AnswerModel.Phase) {
        guard var t = task, isRunning else { return }
        isRunning = false
        runner = nil
        card.model.phase = phase
        switch phase {
        case .done: t.status = .done; host.asked()
        case .failed: t.status = .failed
        default: t.status = .cancelled
        }
        task = t
        save(t)
        DiagnosticsLog.write("ask: \(t.status.rawValue) in \(Self.seconds(t.durationMS)), $\(String(format: "%.4f", t.costUSD)), \(t.contextTokens) context tokens, tools \(t.toolsUsed)")
        host.refresh()
        guard t.status == .done else {
            if case .failed = phase { host.react(.sorry) }
            return
        }
        let kind: AnswerKind = card.model.shape.map { AnswerKind($0.shape) } ?? .repo
        card.model.actions = ActionRanker.actions(for: ActionContext(
            kind: kind, frontmostApp: currentApp, installed: installedTargets, preferredHandoff: preferredHandoff,
            question: currentQuestion ?? "", answer: card.model.copyText))
        if card.isOpen {
            host.react(.handOver)
        } else {
            let first = t.result.split(separator: "\n").first.map(String.init) ?? t.result
            host.submit(InboxItem(id: "ask:\(t.id)", kind: .agent, senderName: "Hush", subject: "Answer ready",
                                  snippet: String(first.prefix(120)), receivedAt: Date(), project: t.repoName))
        }
    }

    func reopen() { card.show(above: host.anchor()) }

    private func save(_ t: AgentTask) { Task { try? await host.engine.save(t) } }

    static func describe(tool: String, repo: String) -> String {
        switch tool {
        case "Read": "Reading files…"
        case "Grep", "Glob": "Searching \(repo)…"
        case "Bash": "Checking git…"
        default: "Working…"
        }
    }

    static func money(_ usd: Double) -> String { usd < 0.001 ? "<$0.001" : "$" + String(format: "%.3f", usd) }

    /// "1.1 s" under 10 s, then whole seconds ("22 s").
    static func seconds(_ ms: Int) -> String {
        ms < 10_000 ? String(format: "%.1f s", Double(ms) / 1000) : "\(Int((Double(ms) / 1000).rounded())) s"
    }

    /// "Haiku" for the alias, the id itself when pinned.
    static func modelName(_ model: String) -> String { ModelAlias(rawValue: model).map { $0.rawValue.capitalized } ?? model }
}

/// The model check's answer, handed from the runner's queue.
private final class PickBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?
    func set(_ d: Data) { lock.lock(); value = d; lock.unlock() }
    var data: Data? { lock.lock(); defer { lock.unlock() }; return value }
}
