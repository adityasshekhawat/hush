import Foundation

/// "While you were away" (opt-in): what one Claude Code session did in a time window, built locally from its
/// transcript (`~/.claude/projects/<project>/<session>.jsonl`). No model involved; pure, so it's testable.
public struct SessionDigest: Sendable, Equatable, Identifiable {
    public enum Status: String, Sendable { case working, finished, stopped }

    public var id: String { sessionID }
    public var sessionID: String
    public var cwd: String
    public var branch: String?
    /// Claude Code's own title for the session, else your first prompt.
    public var title: String
    public var prompts: Int
    public var firstPrompt: String?
    public var lastPrompt: String?
    /// Absolute paths of files edited, in first-edit order.
    public var filePaths: [String]
    /// The same, relative to `cwd` (the repo root after `rebased(to:)`).
    public var filesChanged: [String] { filePaths.map { TranscriptParser.relative($0, to: cwd) } }
    public var commands: Int
    public var commits: Int
    public var pullRequests: [String]
    /// Claude's last message in the window (trimmed).
    public var lastMessage: String?
    public var start: Date
    public var end: Date
    public var status: Status

    public var project: String { URL(fileURLWithPath: cwd).lastPathComponent }

    /// Re-anchor to a folder (the git repo root): sessions often drift into subfolders.
    public func rebased(to root: String) -> SessionDigest {
        var d = self
        d.cwd = root
        return d
    }

    /// Did anything worth reporting happen?
    public var isEmpty: Bool { prompts == 0 && filePaths.isEmpty && commands == 0 && lastMessage == nil }

    /// A compact, capped excerpt for the optional "Summarise" call (the only thing that ever leaves the Mac).
    public var excerpt: String {
        var s = "Project: \(project)\(branch.map { " (branch \($0))" } ?? "")\nTitle: \(title)\n"
        if let p = firstPrompt { s += "First request: \(p.prefix(400))\n" }
        if let p = lastPrompt, p != firstPrompt { s += "Latest request: \(p.prefix(400))\n" }
        if !filesChanged.isEmpty { s += "Files changed: \(filesChanged.prefix(15).joined(separator: ", "))\n" }
        s += "Commands run: \(commands), commits: \(commits)\n"
        if !pullRequests.isEmpty { s += "PRs: \(pullRequests.joined(separator: ", "))\n" }
        if let m = lastMessage { s += "Claude's last message: \(m.prefix(1200))\n" }
        return s
    }
}

public enum TranscriptParser {
    static let editTools: Set<String> = ["Edit", "Write", "MultiEdit", "NotebookEdit"]

    // ISO8601DateFormatter is documented thread-safe; Swift can't see that.
    nonisolated(unsafe) static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let isoPlain = ISO8601DateFormatter()

    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s) ?? isoPlain.date(from: s)
    }

    /// Digest the records that fall inside `window`. `modified`: the file's modification time (a session touched in
    /// the last minute counts as still working). Returns nil if nothing happened in the window.
    public static func digest(lines: [Substring], sessionID: String, window: DateInterval,
                              modified: Date, now: Date) -> SessionDigest? {
        var cwd = "", branch: String?, title: String?
        var prompts: [String] = []
        var files: [String] = []
        var commands = 0, commits = 0
        var prs: [String] = []
        var lastMessage: String?
        var first: Date?, last: Date?
        var lastWasEndTurn = false

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = o["type"] as? String else { continue }
            // Titles have no timestamp; keep the newest one seen.
            if type == "ai-title", let t = o["aiTitle"] as? String { title = t; continue }
            guard let ts = date(o["timestamp"] as? String), window.contains(ts) else { continue }
            if (o["isSidechain"] as? Bool) == true { continue }        // subagents report through their parent
            if let c = o["cwd"] as? String { cwd = c }
            if let b = o["gitBranch"] as? String, !b.isEmpty, b != "HEAD" { branch = b }
            first = first ?? ts
            last = ts

            switch type {
            case "user":
                guard (o["isMeta"] as? Bool) != true, let m = o["message"] as? [String: Any] else { break }
                if let text = userText(m["content"]) {
                    prompts.append(text)
                    lastWasEndTurn = false
                }
            case "assistant":
                guard let m = o["message"] as? [String: Any] else { break }
                for block in m["content"] as? [[String: Any]] ?? [] {
                    switch block["type"] as? String {
                    case "text":
                        if let t = (block["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                            lastMessage = t
                        }
                    case "tool_use":
                        let name = block["name"] as? String ?? ""
                        let input = block["input"] as? [String: Any] ?? [:]
                        if editTools.contains(name), let p = (input["file_path"] as? String) ?? (input["notebook_path"] as? String) {
                            if !files.contains(p) { files.append(p) }
                        }
                        if name == "Bash" {
                            commands += 1
                            if ((input["command"] as? String) ?? "").contains("git commit") { commits += 1 }
                        }
                    default: break
                    }
                }
                lastWasEndTurn = (m["stop_reason"] as? String) == "end_turn"
            case "pr-link":
                if let u = o["prUrl"] as? String, !prs.contains(u) { prs.append(u) }
            default:
                break
            }
        }

        guard let start = first, let end = last else { return nil }
        let status: SessionDigest.Status = now.timeIntervalSince(modified) < 60 ? .working : (lastWasEndTurn ? .finished : .stopped)
        let d = SessionDigest(
            sessionID: sessionID, cwd: cwd, branch: branch,
            title: title ?? prompts.first.map { String($0.prefix(70)) } ?? "Claude Code session",
            prompts: prompts.count, firstPrompt: prompts.first, lastPrompt: prompts.last,
            filePaths: files, commands: commands, commits: commits, pullRequests: prs,
            lastMessage: lastMessage.map { String($0.prefix(600)) }, start: start, end: end, status: status)
        return d.isEmpty ? nil : d
    }

    /// Your typed prompt, not tool results, command echoes or system-injected tags.
    static func userText(_ content: Any?) -> String? {
        var text: String?
        if let s = content as? String { text = s }
        else if let blocks = content as? [[String: Any]] {
            if blocks.contains(where: { $0["type"] as? String == "tool_result" }) { return nil }
            text = blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: "\n")
        }
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, !t.hasPrefix("<") else { return nil }
        return t
    }

    static func relative(_ path: String, to cwd: String) -> String {
        guard !cwd.isEmpty, path.hasPrefix(cwd + "/") else {
            // Outside the folder: keep the last two components so it's still recognisable.
            return URL(fileURLWithPath: path).pathComponents.suffix(2).joined(separator: "/")
        }
        return String(path.dropFirst(cwd.count + 1))
    }
}

/// One line of a session's recent conversation, for the session card's live view.
public struct SessionTurn: Sendable, Equatable, Identifiable {
    public enum Role: Sendable, Equatable { case you, agent, tool }
    public var id: Int
    public var role: Role
    public var text: String
    public var at: Date?
}

extension TranscriptParser {
    /// The last `limit` turns: your prompts, the agent's text, and a short line per tool use ("Edit · Foo.swift").
    public static func recentTurns(lines: [Substring], limit: Int = 30) -> [SessionTurn] {
        var out: [SessionTurn] = []
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = o["type"] as? String, (o["isSidechain"] as? Bool) != true else { continue }
            let at = date(o["timestamp"] as? String)
            switch type {
            case "user":
                guard (o["isMeta"] as? Bool) != true, let m = o["message"] as? [String: Any], let t = userText(m["content"]) else { break }
                out.append(SessionTurn(id: out.count, role: .you, text: String(t.prefix(800)), at: at))
            case "assistant":
                guard let m = o["message"] as? [String: Any] else { break }
                for block in m["content"] as? [[String: Any]] ?? [] {
                    switch block["type"] as? String {
                    case "text":
                        if let t = (block["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                            out.append(SessionTurn(id: out.count, role: .agent, text: String(t.prefix(1200)), at: at))
                        }
                    case "tool_use":
                        out.append(SessionTurn(id: out.count, role: .tool, text: toolLine(block), at: at))
                    default: break
                    }
                }
            default: break
            }
        }
        // Renumber the tail so ids stay stable for the view.
        return out.suffix(limit).enumerated().map { i, t in var t = t; t.id = i; return t }
    }

    /// "Edit · MenuPanel.swift", "Bash · swift test", "Read · docs/PRD.md".
    static func toolLine(_ block: [String: Any]) -> String {
        let name = block["name"] as? String ?? "Tool"
        let input = block["input"] as? [String: Any] ?? [:]
        var detail: String?
        if let p = input["file_path"] as? String {
            detail = URL(fileURLWithPath: p).lastPathComponent
        } else if let c = input["command"] as? String {
            let first = c.split(separator: "\n").first.map(String.init) ?? ""
            detail = String(first.prefix(70))
        } else if let p = input["pattern"] as? String {
            detail = String(p.prefix(50))
        } else if let d = input["description"] as? String {
            detail = String(d.prefix(60))
        }
        guard let detail else { return name }
        return name + " · " + detail
    }
}

/// When to offer a digest (pure rules).
public enum AwayRules {
    /// Gone at least this long before a digest is worth showing.
    public static let minimumAway: TimeInterval = 10 * 60
    /// "Show digest now" from the menu looks back this far.
    public static let manualLookback: TimeInterval = 3 * 3600

    public static func shouldOffer(awaySince: Date?, now: Date) -> Bool {
        guard let s = awaySince else { return false }
        return now.timeIntervalSince(s) >= minimumAway
    }
}
