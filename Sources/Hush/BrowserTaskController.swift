import AppKit
import SwiftUI
import HushCore
import HushMac

/// Browser tasks (docs/lanes-plan.md § L3): plan → you approve → it runs in your browser (Chrome, Comet, …).
/// The model proposes a plan with no tools. Once you approve, Claude Code runs with the Claude in Chrome tools,
/// and every tool call goes through `hushctl gate`, which applies BrowserGate's rules in code and asks you
/// (over a private socket) when a site is off-plan or the model says a step is irreversible.
@MainActor
final class BrowserTaskController {
    struct Host {
        var card: AnswerCard
        var react: (Reaction) -> Void
        var anchor: () -> NSRect
        var refresh: () -> Void
        var submit: (InboxItem) -> Void
        var save: (AgentTask) -> Void
    }

    private enum Stage { case planning, running }

    let host: Host
    private var runner: ClaudeCodeRunner?
    private var stage: Stage = .planning
    private var task: AgentTask?
    private var request = ""
    private var pendingReply: (@Sendable (Bool) -> Void)?
    private var runFiles: [URL] = []
    private(set) var isRunning = false

    /// Agent ▸ Browser tasks ▸ Use: your pick (nil = automatic).
    var preferredBrowser: TaskBrowser? {
        get { UserDefaults.standard.string(forKey: "taskBrowser").flatMap(TaskBrowser.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "taskBrowser") }
    }
    private var browser: TaskBrowser?
    private var notConnected: String {
        let name = browser?.displayName ?? "your browser"
        return "\(name)'s Claude extension isn't connected. Open \(name), click the Claude extension once so it signs in, and try again."
    }
    static let confirmTool = "mcp__hush__confirm"
    static let stepTool = "mcp__hush__step"
    private static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Hush")
    private let gate = GateServer(path: folder.appendingPathComponent("gate.sock").path)

    /// Beside Hush while a task runs with its card closed.
    let pill = TaskStatusPill()

    init(host: Host) {
        self.host = host
        pill.onClick = { [weak self] in
            guard let self else { return }
            self.pill.hide()
            self.host.card.show(above: self.host.anchor())
        }
    }

    /// The card was closed: if a task is still running, keep it visible as the pill.
    func cardClosed() {
        guard isRunning, stage == .running else { return }
        pill.show(text: pillText, color: pillColor, beside: host.anchor())
    }

    private var pillText: String {
        let name = browser?.displayName ?? "the browser"
        guard let total = model.plan?.steps.count else { return "In \(name)" }
        return "In \(name) · \(min(model.currentStep ?? 1, total)) of \(total)"
    }
    private var pillColor: Color { model.prompt != nil ? HushColor.needsYou : HushColor.working }
    private func updatePill() { if pill.isShown { pill.update(text: pillText, color: pillColor) } }

    private var model: AnswerModel { host.card.model }

    // MARK: 1. plan

    func start(_ text: String) {
        stop(silently: true)
        request = text
        browser = TaskBrowser.pick(preferred: preferredBrowser, withExtension: TaskBrowsers.withExtension(),
                                   running: TaskBrowsers.running())
        model.browserName = browser?.displayName
        guard browser != nil else {
            model.phase = .failed("Browser tasks need the Claude extension in Chrome, Comet, Arc, Brave or Edge. Get it at claude.ai/chrome.")
            host.react(.sorry)
            return
        }
        model.plan = nil
        model.steps = []
        model.prompt = nil
        model.phase = .working
        model.activity = "Planning…"
        let spec = LaneSettings.spec(.doIt)
        let t = AgentTask(startedAt: Date(), repo: "browser", prompt: text, model: spec.model)
        task = t
        host.save(t)
        stage = .planning
        launch(LaneOptions.doPlan(text, spec: spec))
        DiagnosticsLog.write("browser: planning (\(text.count) chars)")
    }

    // MARK: 2. run (after Approve)

    func approve() {
        guard let plan = model.plan, !isRunning, var t = task else { return }
        guard let hushctl = Optional(HookInstaller.hushctlPath), FileManager.default.isExecutableFile(atPath: hushctl) else {
            fail("Hush's helper (hushctl) is missing. Reinstall Hush and try again."); return
        }
        guard gate.start() else { fail("Couldn't open Hush's private approval channel."); return }
        guard let browser, TaskBrowsers.ensureManifest(for: browser) else {
            fail("Couldn't connect \(browser?.displayName ?? "the browser") to Claude Code. Reinstall Claude Code's Chrome integration and try again."); return
        }
        let token = UUID().uuidString
        let runs = Self.folder.appendingPathComponent("runs")
        try? FileManager.default.createDirectory(at: runs, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let planURL = runs.appendingPathComponent("\(t.id)-plan.json")
        let mcpURL = runs.appendingPathComponent("\(t.id)-mcp.json")
        let mcp: [String: Any] = ["mcpServers": ["hush": ["command": hushctl, "args": ["gate", gate.path, token, planURL.path]]]]
        guard write((try? JSONEncoder().encode(plan)) ?? Data(), to: planURL),
              write((try? JSONSerialization.data(withJSONObject: mcp)) ?? Data(), to: mcpURL) else {
            fail("Couldn't prepare the task files."); return
        }
        runFiles = [planURL, mcpURL]
        gate.expect(token: token) { [weak self] req, reply in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.ask(req, reply: reply) } }
        }

        let spec = LaneSettings.spec(.doIt)
        var o = ClaudeCodeRunner.Options(cwd: FileManager.default.temporaryDirectory,
                                         prompt: "Do this task now: \(request)", allowedTools: [Self.confirmTool, Self.stepTool])
        o.apply(spec)
        o.chrome = true
        o.mcpConfigPath = mcpURL.path
        o.permissionPromptTool = "mcp__hush__approve"
        o.systemPrompt = plan.runSystemPrompt(confirmTool: Self.confirmTool)
        t.model = spec.model
        task = t
        stage = .running
        model.phase = .working
        model.activity = "Opening \(browser.displayName)…"
        model.currentStep = 1
        model.okCount = 0
        model.runStartedAt = Date()
        DiagnosticsLog.write("browser: approved in \(browser.displayName), \(plan.steps.count) steps on \(plan.domains.joined(separator: ", "))")

        // The extension connects once Chrome is up; give a cold start a moment.
        let coldStart = NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID).isEmpty
        if coldStart, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleID) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: cfg)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (coldStart ? 4 : 0)) { [weak self] in
            guard let self, self.task?.id == t.id, self.stage == .running else { return }
            self.launch(o)
        }
        isRunning = true
        host.refresh()
    }

    // MARK: questions from the gate

    private func ask(_ req: GateRequest, reply: @escaping @Sendable (Bool) -> Void) {
        guard isRunning, stage == .running else { reply(false); return }
        if req.kind == .step {
            if let n = Int(req.text), n > 0 { model.currentStep = n }
            reply(true)
            updatePill()
            return
        }
        pendingReply?(false)          // one question at a time; an older one counts as no
        pendingReply = reply
        let prompt = GatePrompt(kind: req.kind, text: req.text)
        model.prompt = prompt
        updatePill()
        // The gate stops waiting after 300 s and counts it as no; clear the question before then so a late tap
        // can't look like it worked.
        DispatchQueue.main.asyncAfter(deadline: .now() + 290) { [weak self] in
            guard let self, self.model.prompt?.id == prompt.id else { return }
            self.answer(false)
            self.model.activity = "No answer, so I skipped that step"
        }
        model.activity = "Waiting for you…"
        if !host.card.isOpen { pill.hide(); host.card.show(above: host.anchor()) }
        host.react(.perk)
        DiagnosticsLog.write("browser: asked (\(req.kind.rawValue))")
    }

    func answer(_ ok: Bool) {
        guard let reply = pendingReply else { return }
        pendingReply = nil
        reply(ok)
        if ok { model.okCount += 1 }
        model.prompt = nil
        updatePill()
        model.activity = ok ? "Carrying on…" : "Stopping that step…"
        DiagnosticsLog.write("browser: answered \(ok ? "yes" : "no")")
    }

    // MARK: running claude

    private func launch(_ o: ClaudeCodeRunner.Options) {
        let r = ClaudeCodeRunner(options: o)
        runner = r
        isRunning = true
        let id = task?.id ?? ""
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            r.run { event in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.handle(event, taskID: id) } }
            }
        }
    }

    private func handle(_ e: ClaudeCodeRunner.Event, taskID: String) {
        guard var t = task, t.id == taskID, runner != nil else { return }
        switch e {
        case .structured(let data):
            if stage == .planning { model.plan = try? JSONDecoder().decode(TaskPlan.self, from: data) }
        case .tool(let name):
            if !t.toolsUsed.contains(name) { t.toolsUsed.append(name) }
            let step = Self.describe(tool: name)
            if stage == .running { model.activity = step + "…" }
            // Planning has no browser steps (its only tool is the structured answer).
            if stage == .running, name.hasPrefix("mcp__claude-in-chrome__"), model.steps.last != step { model.steps.append(step) }
        case .denied(let what):
            // Claude Code also lists browser tools that errored here, so this is a log line, not a card step.
            DiagnosticsLog.write("browser: denied or errored \(what.prefix(80))")
        case .finished(let result, let cost, _, let ms, _):
            t.costUSD += cost
            t.durationMS += ms
            task = t
            stage == .planning ? planned(result) : done(result)
            return
        case .failed(let why):
            fail(why.contains("not connected") || why.contains("extension")
                 ? notConnected
                 : (why.count > 160 ? "Something went wrong. Try again." : why))
            return
        case .cancelled:
            finish(.cancelled)
            return
        case .started, .text:
            break
        }
        task = t
    }

    private func planned(_ result: String) {
        runner = nil
        isRunning = false
        guard let plan = model.plan, !plan.steps.isEmpty else {
            model.text = model.plan?.summary ?? result
            finish(.done)
            return
        }
        model.phase = .awaitingApproval
        host.react(.handOver)
        host.card.resize()
        DiagnosticsLog.write("browser: plan ready, \(plan.steps.count) steps, irreversible \(plan.hasIrreversibleSteps)")
    }

    private func done(_ result: String) {
        let lower = result.lowercased()
        if lower.contains("extension is not connected") || lower.contains("extension isn't connected") {
            fail(notConnected)
            return
        }
        let parsed = TaskPlan.parseResult(result)
        model.text = parsed.text
        model.resultURL = parsed.url
        if let n = model.plan?.steps.count { model.currentStep = n + 1 }
        finish(.done)
    }

    private func fail(_ why: String) {
        task?.result = why
        finish(.failed(why))
    }

    private func finish(_ phase: AnswerModel.Phase) {
        pill.hide()
        pendingReply?(false)
        pendingReply = nil
        model.prompt = nil
        runner = nil
        isRunning = false
        gate.expect(token: nil, handler: nil)
        runFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        runFiles = []
        model.phase = phase
        guard var t = task else { return }
        switch phase {
        case .done: t.status = .done
        case .failed: t.status = .failed
        default: t.status = .cancelled
        }
        if t.result.isEmpty { t.result = model.text }
        task = t
        host.save(t)
        model.footer = ""
        DiagnosticsLog.write("browser: \(t.status.rawValue), $\(String(format: "%.3f", t.costUSD)), tools \(t.toolsUsed)")
        host.refresh()
        if case .failed = phase { host.react(.sorry); return }
        guard t.status == .done, stage == .running else { return }
        if host.card.isOpen { host.react(.handOver) } else {
            host.submit(InboxItem(id: "browser:\(t.id)", kind: .agent, senderName: "Hush", subject: "Browser task done",
                                  snippet: String(t.result.prefix(120)), receivedAt: Date(), project: nil))
        }
    }

    func stop(silently: Bool = false) {
        guard isRunning || model.phase == .awaitingApproval else { return }
        stage = .running   // so a cancelled plan doesn't come back
        runner?.cancel()
        if silently {
            pendingReply?(false)
            pendingReply = nil
            runner = nil
            isRunning = false
            gate.expect(token: nil, handler: nil)
        } else {
            finish(.cancelled)
        }
    }

    // MARK: helpers

    private func write(_ data: Data, to url: URL) -> Bool {
        FileManager.default.createFile(atPath: url.path, contents: data, attributes: [.posixPermissions: 0o600])
    }

    static func describe(tool: String) -> String {
        switch tool.replacingOccurrences(of: "mcp__claude-in-chrome__", with: "") {
        case "tabs_context_mcp", "tabs_create_mcp", "list_connected_browsers": "Opening a tab"
        case "navigate": "Going to the page"
        case "read_page", "get_page_text", "find": "Reading the page"
        case "computer", "browser_batch": "Working in the page"
        case "form_input": "Filling in a field"
        case "tabs_close_mcp": "Closing the tab"
        case confirmTool: "Asking you"
        default: "Working"
        }
    }
}
