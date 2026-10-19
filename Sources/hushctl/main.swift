// hushctl: run by Claude Code hooks (`hushctl hook`, hook JSON on stdin), and as the browser-task gate (`hushctl gate`).
//
// Forwards a deliberately thin status event to Hush: session id, folder, event kind, the app hosting the
// session and its terminal device; for a permission request, the tool and up to 200 characters of what it wants to
// run or touch; for a failed run, the error type (ADR-024). Your prompt and Claude's replies are never read past parsing
// or forwarded. It sends over Hush's private socket (0600, this user only), never a broadcast. It never prints (a
// PermissionRequest hook's output could become a decision; silence means "no decision"), always exits 0, returns fast.
import AppKit
import Foundation
import HushCore

func finish() -> Never { exit(0) }

// `hushctl gate …`: the permission gate for Hush's browser tasks (Gate.swift).
if CommandLine.arguments.dropFirst().first == "gate" { runGate(Array(CommandLine.arguments.dropFirst(2))) }
guard CommandLine.arguments.dropFirst().first == "hook" else { finish() }
// Hush's own agent runs report through the runner, not through hooks.
if ProcessInfo.processInfo.environment["HUSH_AGENT_RUN"] == "1" { finish() }
let input = FileHandle.standardInput.readData(ofLength: 1 << 20)
guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
      let event = json["hook_event_name"] as? String,
      let session = json["session_id"] as? String,
      let cwd = json["cwd"] as? String else { finish() }

// `hushctl hook --agent codex`: Codex hooks (same stdin fields; PermissionRequest is its "needs you").
let agent = CommandLine.arguments.firstIndex(of: "--agent").flatMap { i in
    i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : nil
} == "codex" ? "codex" : "claude"

let kind: String
switch event {
case "PermissionRequest": kind = "needsYou"
case "StopFailure": kind = "error"
case "SessionStart": kind = "start"
case "UserPromptSubmit": kind = "prompt"
case "PostToolUse": kind = "tool"
case "Stop": kind = "stop"
case "SessionEnd": kind = "end"
case "Notification":
    // Only permission prompts matter ("waiting for your input" after a Stop is already covered by Stop).
    let type = (json["notification_type"] as? String ?? "").lowercased()
    let message = (json["message"] as? String ?? "").lowercased()
    guard type.contains("permission") || message.contains("permission") else { finish() }
    kind = "needsYou"
default: finish()
}

/// The GUI app hosting this session: walk up the parent processes until one is a regular app (Terminal, iTerm, Cursor…).
func hostApp() -> String? {
    var pid = getppid()
    for _ in 0..<12 where pid > 1 {
        if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular,
           let id = app.bundleIdentifier { return id }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        pid = info.kp_eproc.e_ppid
    }
    return nil
}

/// The terminal device the session runs on (/dev/ttys003), so Hush can find its tab when you send it a message.
/// The hook's own stdin is a pipe, so look at the parent processes' controlling terminal.
func sessionTTY() -> String? {
    var pid = getppid()
    for _ in 0..<6 where pid > 1 {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        let dev = info.kp_eproc.e_tdev
        if dev != -1, let name = devname(dev, S_IFCHR) { return "/dev/" + String(cString: name) }
        pid = info.kp_eproc.e_ppid
    }
    return nil
}

var info: [String: String] = ["v": "1", "event": kind, "session": session, "cwd": cwd]
if kind == "needsYou", let tool = json["tool_name"] as? String {
    info["tool"] = String(tool.prefix(64))
    if let input = json["tool_input"] as? [String: Any], let d = AgentRequest.detail(tool: tool, input: input) { info["detail"] = d }
}
if kind == "error", let e = json["error"] as? String { info["error"] = String(e.prefix(32)) }
if let tty = sessionTTY() { info["tty"] = tty }
if agent != "claude" { info["agent"] = agent }
if let app = hostApp() { info["app"] = app }
sendToHush(info)
finish()

/// One JSON line to Hush's agent socket; if Hush isn't running there's nobody to tell, so give up quietly.
func sendToHush(_ info: [String: String]) {
    guard var line = try? JSONSerialization.data(withJSONObject: info) else { return }
    line.append(0x0A)
    let path = AgentChannel.socketPath
    let s = socket(AF_UNIX, SOCK_STREAM, 0)
    guard s >= 0 else { return }
    defer { close(s) }
    var tv = timeval(tv_sec: 1, tv_usec: 0)
    setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return }
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        for (i, b) in bytes.enumerated() { buf[i] = b }
        buf[bytes.count] = 0
    }
    let ok = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard ok == 0 else { return }
    _ = line.withUnsafeBytes { write(s, $0.baseAddress, line.count) }
}
