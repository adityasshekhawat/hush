import Foundation

/// What an agent asked permission for (ADR-024): the tool, and a short detail from its input (a command, a file, an
/// address). hushctl sends it over Hush's private socket, it's kept in memory only, and it never leaves the Mac.
public struct AgentRequest: Sendable, Equatable {
    public var tool: String
    public var detail: String?

    public init(tool: String, detail: String? = nil) {
        self.tool = tool
        self.detail = detail
    }

    /// The most a hook forwards from the tool input.
    public static let maxDetail = 200

    /// The part of a tool's input worth showing, from the hook's `tool_input`, flattened and capped. Used by hushctl.
    public static func detail(tool: String, input: [String: Any]) -> String? {
        // Codex edits files with apply_patch, whose `command` is the whole patch: keep only what it changes.
        if tool == "apply_patch" {
            guard let patch = input["command"] as? String else { return nil }
            let files = patchFiles(patch)
            return files.isEmpty ? nil : clean(files.map { "\($0.verb) \($0.path)" }.joined(separator: ", "))
        }
        let keys: [String]
        switch tool {
        case "Bash": keys = ["command"]
        case "Edit", "Write", "MultiEdit", "NotebookEdit", "Read": keys = ["file_path", "notebook_path"]
        case "WebFetch": keys = ["url"]
        case "WebSearch": keys = ["query"]
        case "Task", "Agent": keys = ["description"]
        default: keys = ["command", "file_path", "url", "path"]
        }
        guard let raw = keys.lazy.compactMap({ input[$0] as? String }).first else { return nil }
        return clean(raw)
    }

    /// One line, no control characters, at most `maxDetail` characters.
    public static func clean(_ s: String) -> String? {
        let flat = s.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }.joined()
            .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        guard !flat.isEmpty else { return nil }
        return flat.count > maxDetail ? String(flat.prefix(maxDetail - 1)) + "…" : flat
    }

    /// "wants to run rm -rf build", "wants to edit Settings.swift": what the card says (rules, no model).
    public var line: String {
        let d = detail.map { $0.count > 60 ? String($0.prefix(59)) + "…" : $0 }
        switch tool {
        case "Bash": return d.map { "wants to run \($0)" } ?? "wants to run a command"
        case "Edit", "MultiEdit", "NotebookEdit": return detail.map { "wants to edit \(Self.fileName($0))" } ?? "wants to edit a file"
        case "Write": return detail.map { "wants to write \(Self.fileName($0))" } ?? "wants to write a file"
        case "Read": return detail.map { "wants to read \(Self.fileName($0))" } ?? "wants to read a file"
        case "WebFetch": return detail.map { "wants to open \(Self.host($0))" } ?? "wants to open a web page"
        case "WebSearch": return d.map { "wants to search for \($0)" } ?? "wants to search the web"
        case "apply_patch":
            let files = patchEntries
            if files.count == 1, let f = files.first {
                return "wants to \(f.verb == "add" ? "create" : f.verb) \(Self.fileName(f.path))"
            }
            return files.isEmpty ? "wants to change files"
                : "wants to change \(files.count) files (\(files.prefix(2).map { Self.fileName($0.path) }.joined(separator: ", "))\(files.count > 2 ? "…" : ""))"
        default:
            if tool.hasPrefix("mcp__") {
                let parts = tool.split(separator: "_", omittingEmptySubsequences: true)
                return "wants to use \(parts.dropFirst().first.map(String.init) ?? "a tool") (\(parts.last.map(String.init) ?? tool))"
            }
            return "wants to use \(tool)"
        }
    }

    /// The files a Codex patch touches, from its `*** Add/Update/Delete File:` headers: ("add" | "edit" | "delete", path).
    public static func patchFiles(_ patch: String) -> [(verb: String, path: String)] {
        patch.split(whereSeparator: \.isNewline).compactMap { line in
            let l = line.trimmingCharacters(in: .whitespaces)
            for (head, verb) in [("*** Add File: ", "add"), ("*** Update File: ", "edit"), ("*** Delete File: ", "delete")] where l.hasPrefix(head) {
                let path = l.dropFirst(head.count).trimmingCharacters(in: .whitespaces)
                return path.isEmpty ? nil : (verb, path)
            }
            return nil
        }
    }

    /// A patch's detail ("edit src/app.ts, delete .env") back into (verb, path) pairs.
    var patchEntries: [(verb: String, path: String)] {
        (detail ?? "").components(separatedBy: ", ").compactMap { e in
            let parts = e.split(separator: " ", maxSplits: 1).map(String.init)
            return parts.count == 2 && ["add", "edit", "delete"].contains(parts[0]) ? (parts[0], parts[1]) : nil
        }
    }

    static func fileName(_ path: String) -> String { URL(fileURLWithPath: path).lastPathComponent }
    static func host(_ url: String) -> String { URL(string: url)?.host ?? url }
}

/// Requests worth a careful look, decided by rules in code, never by a model (ADR-021, ADR-024). Returns a short reason,
/// or nil for an ordinary request.
public enum AgentRisk {
    static let patterns: [(String, String)] = [
        (#"\brm\s+(-[a-z]*[rf][a-z]*\s+)+"#, "deletes files"),
        (#"\bgit\s+push\b[^|;&]*(\s-f\b|--force)"#, "force-pushes"),
        (#"\bgit\s+(reset\s+--hard|clean\s+-[a-z]*f)"#, "throws away changes"),
        (#"\bsudo\b"#, "runs as admin"),
        (#"(?i)\b(drop\s+(table|database|schema)|truncate\s+table)\b"#, "drops data"),
        (#"(?i)\bdelete\s+from\s+\w+\s*(;|$)"#, "deletes every row"),
        (#"\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba|z)?sh\b"#, "runs a downloaded script"),
        (#"\b(kubectl\s+delete|terraform\s+(destroy|apply)|pulumi\s+(destroy|up))\b"#, "changes infrastructure"),
        (#"\b(npm|pnpm|yarn|cargo|gem|twine)\s+publish\b|\bgh\s+release\s+create\b"#, "publishes"),
        (#"\b(mkfs|dd\s+if=|diskutil\s+erase)"#, "erases a disk"),
        (#"\bchmod\s+(-R\s+)?777\b"#, "opens up permissions"),
        (#"(?i)(^|[\s/=._-])(prod|production)([\s/=._-]|$)"#, "touches production"),
        (#"(?i)(\.env\b|id_rsa|id_ed25519|\.ssh/|\.aws/credentials|\bsecrets?\b|api[_-]?key|password|\btokens?\b)"#, "touches secrets"),
    ]

    public static func reason(_ r: AgentRequest) -> String? {
        guard let d = r.detail else { return nil }
        // A Codex patch: deleting files, or touching secrets or production paths.
        if r.tool == "apply_patch" {
            if r.patchEntries.contains(where: { $0.verb == "delete" }) { return "deletes files" }
            let paths = r.patchEntries.map(\.path).joined(separator: " ")
            return patterns.filter { $0.1 == "touches secrets" || $0.1 == "touches production" }
                .first { paths.range(of: $0.0, options: .regularExpression) != nil }?.1
        }
        // File tools only matter for secrets and production paths; commands get every rule.
        let rules = r.tool == "Bash" ? patterns : patterns.filter { $0.1 == "touches secrets" || $0.1 == "touches production" }
        return rules.first { d.range(of: $0.0, options: .regularExpression) != nil }?.1
    }
}

/// How a stopped run reads on the card, from StopFailure's `error` (ADR-024).
public enum AgentFailure {
    public static let known = ["rate_limit", "overloaded", "authentication_failed", "oauth_org_not_allowed",
                               "account_on_hold", "billing_error", "invalid_request", "model_not_found", "server_error",
                               "max_output_tokens", "cloud_credential_error", "unknown"]

    public static func text(_ error: String?) -> String {
        switch error {
        case "rate_limit": "Hit a usage limit"
        case "overloaded", "server_error": "Anthropic's servers had trouble"
        case "authentication_failed", "oauth_org_not_allowed", "cloud_credential_error": "Got signed out"
        case "account_on_hold", "billing_error": "A billing or account problem"
        case "max_output_tokens": "Ran out of room for its answer"
        case "model_not_found", "invalid_request": "The request was refused"
        default: "An error stopped it"
        }
    }
}
