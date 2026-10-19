import Foundation

/// Runs one Claude Code task headlessly (`claude -p --output-format stream-json`) and streams what happens.
/// Builder-only backend (ADR-012): uses your own Claude Code login, so it is not for anyone else's Mac.
///
/// Safety defaults: a per-run settings file with no hooks of ours, an explicit tool allowlist, a turn cap,
/// a spend cap, a wall-clock timeout, and session persistence off. Cancel terminates the whole process group.
public final class ClaudeCodeRunner: @unchecked Sendable {
    public struct Options: Sendable {
        public var cwd: URL
        public var prompt: String
        /// Claude Code tool names / patterns, e.g. ["Read", "Grep", "Glob", "Bash(git log:*)"].
        public var allowedTools: [String]
        public var model: String = "sonnet"
        public var maxTurns: Int = 12
        public var maxBudgetUSD: Double = 0.50
        public var timeout: TimeInterval = 180
        /// Structured output: the run must end with JSON matching this schema (delivered as `.structured`).
        public var jsonSchema: String?
        /// Browser tasks: load the Claude in Chrome tools (`--chrome`).
        public var chrome = false
        /// Extra MCP servers (a JSON file), e.g. Hush's permission gate.
        public var mcpConfigPath: String?
        /// Tool calls outside the allowlist go to this MCP tool for a decision instead of being refused.
        public var permissionPromptTool: String?
        /// Replaces Claude Code's default system prompt (lean profile). nil keeps the default.
        public var systemPrompt: String? = Self.leanSystemPrompt

        public static let leanSystemPrompt = """
            You are Hush's background helper for a developer, working in the current repository. Be brief: answer in a \
            few sentences or a short list, plain text, no preamble. Use tools only as much as needed to be correct. \
            Never modify files unless the task explicitly asks you to and the tool is available.
            """

        public init(cwd: URL, prompt: String, allowedTools: [String]) {
            self.cwd = cwd
            self.prompt = prompt
            self.allowedTools = allowedTools
        }
    }

    public enum Event: Sendable, Equatable {
        case started(sessionID: String)
        /// A chunk of Claude's visible reply (streamed).
        case text(String)
        /// Claude is using a tool (name only).
        case tool(String)
        case finished(result: String, costUSD: Double, turns: Int, durationMS: Int, contextTokens: Int)
        /// A tool call the allowlist refused (e.g. "Bash: git log -3 --stat | head"). Reported with the result.
        case denied(String)
        /// The run's structured output (JSON, when `jsonSchema` was set). Sent just before `.finished`.
        case structured(Data)
        case failed(String)
        case cancelled
    }

    public let options: Options
    private var process: Process?
    private var cancelled = false
    private let lock = NSLock()

    public init(options: Options) { self.options = options }

    /// The `claude` binary: PATH lookup via a login shell, since GUI apps don't inherit your shell PATH.
    public static func locateClaude() -> String? {
        for p in ["\(NSHomeDirectory())/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        where FileManager.default.isExecutableFile(atPath: p) { return p }
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/zsh")
        sh.arguments = ["-lc", "command -v claude"]
        let out = Pipe()
        sh.standardOutput = out
        sh.standardError = FileHandle.nullDevice
        try? sh.run()
        sh.waitUntilExit()
        let path = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    func arguments() -> [String] {
        var a = ["-p", options.prompt,
                 "--output-format", "stream-json", "--verbose", "--include-partial-messages",
                 "--model", options.model,
                 "--max-turns", String(options.maxTurns),
                 "--max-budget-usd", String(format: "%.2f", options.maxBudgetUSD),
                 "--no-session-persistence",
                 // Lean context (ADR-013): no MCP servers, project settings only (skips your global CLAUDE.md,
                 // plugins and hooks; the repo's own CLAUDE.md still loads), slash-command skills off.
                 "--strict-mcp-config", "--setting-sources", "project", "--disable-slash-commands"]
        // Load only the built-in tools the allowlist mentions ("Bash(git log:*)" → Bash); tool definitions are
        // a large share of every request.
        let builtins = Array(Set(options.allowedTools.map { String($0.prefix { $0 != "(" }) }
            .filter { !$0.hasPrefix("mcp__") })).sorted()
        a += ["--tools"] + (builtins.isEmpty ? [""] : builtins)
        if !options.allowedTools.isEmpty { a += ["--allowedTools"] + options.allowedTools }
        if let s = options.systemPrompt { a += ["--system-prompt", s] }
        if let schema = options.jsonSchema { a += ["--json-schema", schema] }
        if let tool = options.permissionPromptTool {
            // Outside the allowlist, our gate decides (docs/lanes-plan.md § L3).
            a += ["--permission-prompts", "host", "--permission-prompt-tool", tool]
        } else {
            // Tools outside the allowlist are refused rather than prompting (nobody is at a terminal).
            a += ["--permission-mode", "dontAsk"]
        }
        if let m = options.mcpConfigPath { a += ["--mcp-config", m] }
        if options.chrome { a.append("--chrome") }
        return a
    }

    /// Runs to completion, calling `onEvent` from a background queue. Always ends with finished/failed/cancelled.
    public func run(onEvent: @escaping @Sendable (Event) -> Void) {
        guard let claude = Self.locateClaude() else { onEvent(.failed("Claude Code isn't installed (no `claude` on PATH)")); return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: claude)
        p.arguments = arguments()
        p.currentDirectoryURL = options.cwd
        p.standardInput = FileHandle.nullDevice
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        var env = ProcessInfo.processInfo.environment
        env["HUSH_AGENT_RUN"] = "1"   // so hushctl can ignore Hush's own runs
        p.environment = env

        lock.lock(); process = p; let wasCancelled = cancelled; lock.unlock()
        if wasCancelled { onEvent(.cancelled); return }
        do { try p.run() } catch { onEvent(.failed("couldn't start claude: \(error.localizedDescription)")); return }

        let deadline = DispatchWorkItem { [weak self] in self?.cancel(reason: "timeout") }
        DispatchQueue.global().asyncAfter(deadline: .now() + options.timeout, execute: deadline)

        var buffer = Data()
        var ended = false
        let handle = out.fileHandleForReading
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                for e in Self.parse(line: Data(line)) {
                    if case .finished = e { ended = true }
                    onEvent(e)
                }
            }
        }
        p.waitUntilExit()
        deadline.cancel()
        lock.lock(); let c = cancelled; let reason = cancelReason; lock.unlock()
        if c { onEvent(reason == "timeout" ? .failed("timed out after \(Int(options.timeout)) s") : .cancelled); return }
        if !ended {
            let e = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            onEvent(.failed(e.isEmpty ? "claude exited with status \(p.terminationStatus)" : String(e.prefix(400))))
        }
    }

    private var cancelReason: String?

    public func cancel() { cancel(reason: "user") }

    private func cancel(reason: String) {
        lock.lock()
        cancelled = true
        cancelReason = cancelReason ?? reason
        let p = process
        lock.unlock()
        guard let p, p.isRunning else { return }
        p.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
    }

    /// One stream-json line → events. Unknown shapes are ignored (the format grows over time).
    static func parse(line: Data) -> [Event] {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any], let type = obj["type"] as? String else { return [] }
        switch type {
        case "system":
            if obj["subtype"] as? String == "init", let sid = obj["session_id"] as? String { return [.started(sessionID: sid)] }
        case "stream_event":
            guard let ev = obj["event"] as? [String: Any] else { return [] }
            if ev["type"] as? String == "content_block_delta", let d = ev["delta"] as? [String: Any],
               d["type"] as? String == "text_delta", let t = d["text"] as? String { return [.text(t)] }
            if ev["type"] as? String == "content_block_start", let b = ev["content_block"] as? [String: Any],
               b["type"] as? String == "tool_use", let name = b["name"] as? String { return [.tool(name)] }
        case "result":
            let isError = obj["is_error"] as? Bool ?? false
            let result = obj["result"] as? String ?? ""
            if isError || (obj["subtype"] as? String ?? "success") != "success" {
                return [.failed(result.isEmpty ? (obj["subtype"] as? String ?? "error") : result)]
            }
            var events: [Event] = []
            if let so = obj["structured_output"], !(so is NSNull),
               let data = try? JSONSerialization.data(withJSONObject: so) { events.append(.structured(data)) }
            for d in obj["permission_denials"] as? [[String: Any]] ?? [] {
                let name = d["tool_name"] as? String ?? "?"
                let input = d["tool_input"] as? [String: Any] ?? [:]
                let detail = (input["command"] as? String) ?? (input["file_path"] as? String) ?? ""
                events.append(.denied("\(name): \(detail.prefix(160))"))
            }
            let u = obj["usage"] as? [String: Any] ?? [:]
            let context = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"].reduce(0) { $0 + (u[$1] as? Int ?? 0) }
            return events + [.finished(result: result, costUSD: obj["total_cost_usd"] as? Double ?? 0,
                              turns: obj["num_turns"] as? Int ?? 0, durationMS: obj["duration_ms"] as? Int ?? 0,
                              contextTokens: context)]
        default: break
        }
        return []
    }
}
