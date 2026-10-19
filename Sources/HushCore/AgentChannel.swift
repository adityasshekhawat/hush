import Foundation

/// The channel from `hushctl` (run by agent hooks) to Hush (ADR-024): a Unix socket in Hush's Application Support folder,
/// 0600, so only this user's processes can connect, and nothing is broadcast to other apps. One JSON line of strings
/// per event. Status only: nothing on this channel can start a task or run a command.
public enum AgentChannel {
    public static var socketPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Hush/agent.sock").path
    }

    /// Exactly the expected keys and shapes, or nothing.
    public static func event(from info: [String: String], at now: Date) -> AgentSessionEvent? {
        let allowed: Set<String> = ["v", "event", "session", "cwd", "app", "agent", "tty", "tool", "detail", "error"]
        guard Set(info.keys).isSubset(of: allowed), info["v"] == "1",
              let kindRaw = info["event"], let kind = AgentSessionEvent.Kind(rawValue: kindRaw),
              let session = info["session"], matches(session, #"^[A-Za-z0-9-]{8,64}$"#),
              let cwd = info["cwd"], cwd.hasPrefix("/"), cwd.count < 1024, !cwd.contains("\0") else { return nil }
        var app: String?
        if let a = info["app"] {
            guard matches(a, #"^[A-Za-z0-9.\-]{3,128}$"#) else { return nil }
            app = a
        }
        var agent = AgentKind.claude
        if let a = info["agent"] {
            guard let k = AgentKind(rawValue: a) else { return nil }
            agent = k
        }
        var tty: String?
        if let t = info["tty"] {
            guard matches(t, #"^/dev/ttys[0-9]{1,4}$"#) else { return nil }
            tty = t
        }
        var request: AgentRequest?
        if let tool = info["tool"] {
            guard kind == .needsYou, matches(tool, #"^[A-Za-z0-9_.:\-]{1,64}$"#) else { return nil }
            var detail: String?
            if let d = info["detail"] {
                guard d.count <= AgentRequest.maxDetail, AgentRequest.clean(d) == d else { return nil }
                detail = d
            }
            request = AgentRequest(tool: tool, detail: detail)
        } else if info["detail"] != nil {
            return nil
        }
        var failure: String?
        if let e = info["error"] {
            guard kind == .error, matches(e, #"^[a-z_]{1,32}$"#) else { return nil }
            failure = e
        }
        return AgentSessionEvent(sessionID: session, cwd: cwd, kind: kind, app: app, at: now, agent: agent, tty: tty,
                                 request: request, failure: failure)
    }

    static func matches(_ s: String, _ pattern: String) -> Bool { s.range(of: pattern, options: .regularExpression) != nil }
}
