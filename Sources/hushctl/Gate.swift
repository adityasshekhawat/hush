import Foundation
import HushCore

/// `hushctl gate <socket> <token> <plan.json>`: Hush's permission gate for a browser task (docs/lanes-plan.md § L3).
/// Claude Code starts it as an MCP server and sends it every tool call outside the allowlist (`approve`); the model
/// calls `confirm` before steps it recognises as irreversible. Rules run here, in code (BrowserGate); anything that
/// needs a person goes to Hush over a private socket. No answer, a bad reply or any error means no.
func runGate(_ args: [String]) -> Never {
    guard args.count >= 3, let data = FileManager.default.contents(atPath: args[2]),
          let plan = try? JSONDecoder().decode(TaskPlan.self, from: data) else { exit(2) }
    let socket = args[0], token = args[1]

    func send(_ o: [String: Any]) {
        guard var d = try? JSONSerialization.data(withJSONObject: o) else { return }
        d.append(0x0A)
        FileHandle.standardOutput.write(d)
    }
    func result(_ id: Any, _ r: [String: Any]) { send(["jsonrpc": "2.0", "id": id, "result": r]) }
    func text(_ id: Any, _ s: String) { result(id, ["content": [["type": "text", "text": s]]]) }
    func askHush(_ kind: GateRequest.Kind, _ what: String) -> Bool {
        GateClient.ask(socket: socket, GateRequest(token: token, kind: kind, text: what)) ?? false
    }

    let tools: [[String: Any]] = [
        ["name": "approve", "description": "Hush's permission gate (used by Claude Code, not by you).",
         "inputSchema": ["type": "object", "properties": ["tool_name": ["type": "string"], "input": ["type": "object"],
                                                          "tool_use_id": ["type": "string"]], "required": ["tool_name", "input"]]],
        ["name": "step", "description": "Say which plan step you're starting, so the user can follow along. Returns at once.",
         "inputSchema": ["type": "object", "properties": ["n": ["type": "integer", "description": "The step number, from 1."]],
                         "required": ["n"]]],
        ["name": "confirm", "description": "Ask the user before a step that sends, buys, deletes, submits or posts, or to ask them to sign in. Waits for their answer.",
         "inputSchema": ["type": "object", "properties": ["step": ["type": "string", "description": "One line: what you're about to do."]],
                         "required": ["step"]]],
    ]

    while let line = readLine(strippingNewline: true) {
        guard let m = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
        let id = m["id"], method = m["method"] as? String ?? ""
        let params = m["params"] as? [String: Any] ?? [:]
        switch method {
        case "initialize":
            result(id ?? 0, ["protocolVersion": params["protocolVersion"] as? String ?? "2024-11-05",
                             "capabilities": ["tools": [:]], "serverInfo": ["name": "hush", "version": "1"]])
        case "tools/list":
            result(id ?? 0, ["tools": tools])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let a = params["arguments"] as? [String: Any] ?? [:]
            if name == "step" {
                let n = (a["n"] as? Int) ?? Int(a["n"] as? String ?? "") ?? 0
                if n > 0 { _ = askHush(.step, String(n)) }
                text(id ?? 0, "Noted.")
                continue
            }
            if name == "confirm" {
                let ok = askHush(.confirm, String((a["step"] as? String ?? "Continue?").prefix(300)))
                log("gate: confirm → \(ok ? "yes" : "no")")
                text(id ?? 0, ok ? "The user said yes. Go ahead with this step."
                                 : "The user said no. Don't do this step. Stop and tell them what's left.")
                continue
            }
            let tool = a["tool_name"] as? String ?? ""
            let input = a["input"] as? [String: Any] ?? [:]
            let verdict: Bool
            var reason = ""
            switch BrowserGate.decide(tool: tool, input: input, plan: plan, clicks: .allowAfterApproval) {
            case .allow: verdict = true
            case .deny(let why): verdict = false; reason = why
            case .ask(let question):
                verdict = askHush(.ask, question)
                reason = "the user said no"
            }
            log("gate: \(tool.replacingOccurrences(of: "mcp__claude-in-chrome__", with: "")) → \(verdict ? "allow" : "deny")"
                + (reason.isEmpty ? "" : " (\(reason))") + (BrowserGate.host(of: input["url"] as? String ?? "").map { " \($0)" } ?? ""))
            let reply: [String: Any] = verdict ? ["behavior": "allow", "updatedInput": input]
                                               : ["behavior": "deny", "message": "Hush: \(reason)"]
            let json = (try? JSONSerialization.data(withJSONObject: reply)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
            text(id ?? 0, json)
        default:
            if let id { result(id, [:]) }   // notifications have no id and get no reply
        }
    }
    exit(0)
}

/// One line in Hush's diagnostics log (same file and format as the app's DiagnosticsLog). Never the page content.
func log(_ line: String) {
    let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Hush/diagnostics.log")
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    guard let h = try? FileHandle(forWritingTo: url) else { return }
    defer { try? h.close() }
    _ = try? h.seekToEnd()
    h.write(Data("\(f.string(from: Date())) \(line)\n".utf8))
}

/// One request, one reply, over the app's unix socket. nil on any failure (callers treat it as no).
enum GateClient {
    static func ask(socket path: String, _ req: GateRequest, timeout: Int = 300) -> Bool? {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var tv = timeval(tv_sec: timeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, b) in bytes.enumerated() { buf[i] = b }
            buf[bytes.count] = 0
        }
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0, var out = try? JSONEncoder().encode(req) else { return nil }
        out.append(0x0A)
        guard out.withUnsafeBytes({ write(fd, $0.baseAddress, out.count) }) == out.count else { return nil }
        var reply = Data()
        var buf = [UInt8](repeating: 0, count: 512)
        while !reply.contains(0x0A) {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { return nil }
            reply.append(contentsOf: buf[0..<n])
        }
        return (try? JSONDecoder().decode(GateReply.self, from: reply.prefix { $0 != 0x0A }))?.ok
    }
}
