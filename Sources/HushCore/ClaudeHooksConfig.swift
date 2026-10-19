import Foundation

/// Merges Hush's hooks into a coding agent's hook config (Claude Code's settings.json, Codex's hooks.json; both use
/// the same `hooks` layout) and takes them out again, leaving everything else (like an existing PreToolUse hook)
/// untouched. Pure, so it's testable; file IO lives in the app.
public enum ClaudeHooksConfig {
    /// Every command Hush adds contains this marker, so uninstall only removes Hush's own entries.
    public static let marker = "hushctl"
    public static let events = ["SessionStart", "UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd"]
    /// Codex has no Notification event; PermissionRequest is its "needs you".
    public static let codexEvents = ["SessionStart", "UserPromptSubmit", "PostToolUse", "PermissionRequest", "Stop", "SessionEnd"]

    public static func events(for agent: AgentKind) -> [String] { agent == .claude ? events : codexEvents }

    /// The hook command: never fails, never prints (some hook output is shown to the model), even if Hush is gone.
    public static func command(hushctl path: String, agent: AgentKind = .claude) -> String {
        "[ -x '\(path)' ] && '\(path)' hook\(agent == .claude ? "" : " --agent \(agent.rawValue)") >/dev/null 2>&1; exit 0"
    }

    public static func install(into settings: [String: Any], hushctl path: String, agent: AgentKind = .claude) -> [String: Any] {
        var s = uninstall(from: settings)
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        for event in events(for: agent) {
            var list = hooks[event] as? [[String: Any]] ?? []
            var group: [String: Any] = ["hooks": [["type": "command", "command": command(hushctl: path, agent: agent), "timeout": 5]]]
            if agent == .claude { group["matcher"] = "" }   // Codex: no matcher means every occurrence
            list.append(group)
            hooks[event] = list
        }
        s["hooks"] = hooks
        return s
    }

    public static func uninstall(from settings: [String: Any]) -> [String: Any] {
        var s = settings
        guard var hooks = s["hooks"] as? [String: Any] else { return s }
        for (event, value) in hooks {
            guard let list = value as? [[String: Any]] else { continue }
            let kept = list.compactMap { group -> [String: Any]? in
                guard let inner = group["hooks"] as? [[String: Any]] else { return group }
                let remaining = inner.filter { !(($0["command"] as? String) ?? "").contains(marker) }
                if remaining.isEmpty { return nil }
                var g = group
                g["hooks"] = remaining
                return g
            }
            hooks[event] = kept.isEmpty ? nil : kept
        }
        s["hooks"] = hooks.isEmpty ? nil : hooks
        return s
    }

    /// Hush moved (e.g. build folder → /Applications): point Hush's own hook commands at `path`, leave
    /// everything else alone. Returns nil when nothing needed changing.
    public static func repointed(_ settings: [String: Any], hushctl path: String) -> [String: Any]? {
        guard var hooks = settings["hooks"] as? [String: Any] else { return nil }
        var changed = false
        for (event, value) in hooks {
            guard var list = value as? [[String: Any]] else { continue }
            for gi in list.indices {
                guard var inner = list[gi]["hooks"] as? [[String: Any]] else { continue }
                for hi in inner.indices {
                    guard let c = inner[hi]["command"] as? String, c.contains(marker) else { continue }
                    let wanted = command(hushctl: path, agent: c.contains("--agent codex") ? .codex : .claude)
                    if c != wanted {
                        inner[hi]["command"] = wanted
                        changed = true
                    }
                }
                list[gi]["hooks"] = inner
            }
            hooks[event] = list
        }
        guard changed else { return nil }
        var s = settings
        s["hooks"] = hooks
        return s
    }

    public static func isInstalled(in settings: [String: Any]) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { value in
            (value as? [[String: Any]] ?? []).contains { group in
                (group["hooks"] as? [[String: Any]] ?? []).contains { (($0["command"] as? String) ?? "").contains(marker) }
            }
        }
    }
}
