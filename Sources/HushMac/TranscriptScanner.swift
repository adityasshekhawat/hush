import Foundation
import HushCore

/// Finds Claude Code transcripts touched in a window and digests them (opt-in "While you were away").
/// Reads `~/.claude/projects/*/*.jsonl` on this Mac only. Capped so a huge history can't stall anything.
public enum TranscriptScanner {
    public static let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    static let maxFiles = 12
    /// Only the tail of a large transcript is read (recent activity lives there).
    static let maxBytes = 12 * 1024 * 1024

    /// Off the main thread: file IO and JSON parsing.
    public static func digests(in window: DateInterval, now: Date = Date()) async -> [SessionDigest] {
        await Task.detached(priority: .utility) { scan(window: window, now: now) }.value
    }

    static func scan(window: DateInterval, now: Date) -> [SessionDigest] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        var candidates: [(URL, Date)] = []
        for dir in projects {
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for f in files where f.pathExtension == "jsonl" {
                guard let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                      m >= window.start else { continue }
                candidates.append((f, m))
            }
        }
        return candidates.sorted { $0.1 > $1.1 }.prefix(maxFiles).compactMap { url, modified in
            guard let lines = tailLines(url) else { return nil }
            return TranscriptParser.digest(lines: lines, sessionID: url.deletingPathExtension().lastPathComponent,
                                           window: window, modified: modified, now: now)
                .map { $0.rebased(to: gitRoot(of: $0.cwd)) }
        }
        .sorted { $0.end > $1.end }
    }

    /// One session's recent conversation (for the session card), read from its transcript. Off the main thread.
    public static func recentTurns(sessionID: String, limit: Int = 30) async -> [SessionTurn] {
        await Task.detached(priority: .userInitiated) {
            guard sessionID.range(of: #"^[A-Za-z0-9-]{8,64}$"#, options: .regularExpression) != nil,
                  let url = transcript(for: sessionID), let lines = tailLines(url, bytes: 512 * 1024) else { return [] }
            return TranscriptParser.recentTurns(lines: lines, limit: limit)
        }.value
    }

    /// ~/.claude/projects/<project>/<session id>.jsonl
    static func transcript(for sessionID: String) -> URL? {
        let fm = FileManager.default
        let projects = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return projects.map { $0.appendingPathComponent(sessionID + ".jsonl") }.first { fm.fileExists(atPath: $0.path) }
    }

    /// The nearest folder at or above `path` containing `.git`, else `path` itself.
    static func gitRoot(of path: String) -> String {
        var url = URL(fileURLWithPath: path)
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) { return url.path }
            url.deleteLastPathComponent()
        }
        return path
    }

    static func tailLines(_ url: URL, bytes: Int = maxBytes) -> [Substring]? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let start = size > UInt64(bytes) ? size - UInt64(bytes) : 0
        try? h.seek(toOffset: start)
        guard let data = try? h.readToEnd() else { return nil }
        var text = String(decoding: data, as: UTF8.self)
        if start > 0, let nl = text.firstIndex(of: "\n") { text = String(text[text.index(after: nl)...]) }   // drop the partial first line
        // ai-title lines can sit before the tail; grab the newest title cheaply from the whole file if missing.
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        if start > 0, !lines.contains(where: { $0.contains("\"ai-title\"") }),
           let head = try? String(contentsOf: url, encoding: .utf8).split(separator: "\n").last(where: { $0.contains("\"ai-title\"") }) {
            lines.insert(head, at: 0)
        }
        return lines
    }
}
