import Foundation
import SQLite3

public enum StoreError: Error, CustomStringConvertible {
    case sqlite(String)
    public var description: String {
        switch self { case .sqlite(let m): "SQLite: \(m)" }
    }
}

/// Local SQLite store: decision log (FR-12), confirmed rules, shoo signals. Nothing here leaves the Mac.
/// Not thread-safe on its own; `DecisionEngine` (an actor) is its only owner.
public final class HushStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Pass ":memory:" for tests.
    public init(path: String) throws {
        if path != ":memory:" {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        try exec("PRAGMA journal_mode=WAL;")
        try migrate()
    }

    deinit { sqlite3_close(db) }

    public static func defaultPath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Hush/hush.sqlite").path
    }

    private func migrate() throws {
        try exec("""
            CREATE TABLE IF NOT EXISTS decisions (
              id TEXT PRIMARY KEY,
              at REAL NOT NULL,
              item_id TEXT NOT NULL,
              kind TEXT NOT NULL,
              category TEXT NOT NULL,
              proposed_level INTEGER,
              final_level INTEGER,
              outcome TEXT NOT NULL,
              confidence REAL,
              model_version TEXT,
              reasons TEXT NOT NULL,
              response TEXT,
              responded_at REAL
            );
            CREATE INDEX IF NOT EXISTS decisions_at ON decisions(at);
            CREATE TABLE IF NOT EXISTS rules (id TEXT PRIMARY KEY, json TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS shoos (category TEXT NOT NULL, at REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS agent_tasks (
              id TEXT PRIMARY KEY, started_at REAL NOT NULL, repo TEXT NOT NULL, prompt TEXT NOT NULL,
              status TEXT NOT NULL, result TEXT NOT NULL, tools TEXT NOT NULL, cost_usd REAL NOT NULL,
              duration_ms INTEGER NOT NULL, context_tokens INTEGER NOT NULL, model TEXT NOT NULL
            );
            """)
    }

    // MARK: decisions

    public func insert(_ d: Decision) throws {
        try run(
            """
            INSERT INTO decisions (id, at, item_id, kind, category, proposed_level, final_level, outcome,
                                   confidence, model_version, reasons)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
            """,
            [d.id, d.at.timeIntervalSince1970, d.item.id, d.item.kind.rawValue, d.item.category,
             d.proposedLevel?.rawValue, d.finalLevel?.rawValue, d.outcome.rawValue,
             d.confidence, d.modelVersion, d.reasons.joined(separator: " | ")])
    }

    public func recordResponse(decisionID: String, _ response: UserResponse, at: Date) throws {
        try run("UPDATE decisions SET response = ?, responded_at = ? WHERE id = ?",
                [response.rawValue, at.timeIntervalSince1970, decisionID])
    }

    /// Interrupts actually shown in [start, end): the FR-8 cap counts these.
    public func interruptsShown(from start: Date, to end: Date) throws -> Int {
        try scalarInt(
            "SELECT COUNT(*) FROM decisions WHERE outcome = 'shown' AND final_level = ? AND at >= ? AND at < ?",
            [AttentionLevel.interrupt.rawValue, start.timeIntervalSince1970, end.timeIntervalSince1970])
    }

    /// For the end-of-day "You got 4 things from me today. I held back 63."
    public func daySummary(from start: Date, to end: Date) throws -> DaySummary {
        let range: [Any?] = [start.timeIntervalSince1970, end.timeIntervalSince1970]
        // DISTINCT item_id: a queued item is logged again when it's released, so count items, not rows.
        let shown = try scalarInt(
            "SELECT COUNT(DISTINCT item_id) FROM decisions WHERE outcome = 'shown' AND final_level >= 1 AND at >= ? AND at < ?", range)
        let total = try scalarInt("SELECT COUNT(DISTINCT item_id) FROM decisions WHERE at >= ? AND at < ?", range)
        return DaySummary(shown: shown, heldBack: total - shown)
    }

    public func recentDecisions(limit: Int) throws -> [LoggedDecision] {
        var out: [LoggedDecision] = []
        try query(
            "SELECT id, at, category, final_level, outcome, confidence, model_version, reasons, response FROM decisions ORDER BY at DESC LIMIT ?",
            [limit]
        ) { s in
            out.append(LoggedDecision(
                id: Self.text(s, 0) ?? "",
                at: Date(timeIntervalSince1970: sqlite3_column_double(s, 1)),
                category: Self.text(s, 2) ?? "",
                finalLevel: sqlite3_column_type(s, 3) == SQLITE_NULL ? nil : AttentionLevel(rawValue: Int(sqlite3_column_int(s, 3))),
                outcome: Decision.Outcome(rawValue: Self.text(s, 4) ?? "") ?? .dropped,
                confidence: sqlite3_column_type(s, 5) == SQLITE_NULL ? nil : sqlite3_column_double(s, 5),
                modelVersion: Self.text(s, 6),
                reasons: Self.text(s, 7) ?? "",
                response: Self.text(s, 8).flatMap(UserResponse.init(rawValue:))))
        }
        return out
    }

    // MARK: rules

    public func save(_ rule: UserRule) throws {
        let json = String(decoding: try JSONEncoder().encode(rule), as: UTF8.self)
        try run("INSERT OR REPLACE INTO rules (id, json) VALUES (?, ?)", [rule.id, json])
    }

    public func deleteRule(id: String) throws {
        try run("DELETE FROM rules WHERE id = ?", [id])
    }

    public func rules() throws -> [UserRule] {
        var out: [UserRule] = []
        try query("SELECT json FROM rules", []) { s in
            if let j = Self.text(s, 0), let r = try? JSONDecoder().decode(UserRule.self, from: Data(j.utf8)) {
                out.append(r)
            }
        }
        return out.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: shoos

    public func addShoo(category: String, at: Date) throws {
        try run("INSERT INTO shoos (category, at) VALUES (?, ?)", [category, at.timeIntervalSince1970])
    }

    public func shooCount(category: String) throws -> Int {
        try scalarInt("SELECT COUNT(*) FROM shoos WHERE category = ?", [category])
    }

    // MARK: agent tasks (Phase 2: the local, readable log of what you asked and what it did)

    public func save(_ t: AgentTask) throws {
        try run("""
            INSERT OR REPLACE INTO agent_tasks (id, started_at, repo, prompt, status, result, tools, cost_usd,
                                                duration_ms, context_tokens, model)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
            """,
            [t.id, t.startedAt.timeIntervalSince1970, t.repo, t.prompt, t.status.rawValue, t.result,
             t.toolsUsed.joined(separator: ","), t.costUSD, t.durationMS, t.contextTokens, t.model])
    }

    public func agentTasks(limit: Int) throws -> [AgentTask] {
        var out: [AgentTask] = []
        try query("SELECT id, started_at, repo, prompt, status, result, tools, cost_usd, duration_ms, context_tokens, model FROM agent_tasks ORDER BY started_at DESC LIMIT ?", [limit]) { s in
            var t = AgentTask(id: Self.text(s, 0) ?? "", startedAt: Date(timeIntervalSince1970: sqlite3_column_double(s, 1)),
                              repo: Self.text(s, 2) ?? "", prompt: Self.text(s, 3) ?? "", model: Self.text(s, 10) ?? "")
            t.status = AgentTask.Status(rawValue: Self.text(s, 4) ?? "") ?? .failed
            t.result = Self.text(s, 5) ?? ""
            t.toolsUsed = (Self.text(s, 6) ?? "").split(separator: ",").map(String.init)
            t.costUSD = sqlite3_column_double(s, 7)
            t.durationMS = Int(sqlite3_column_int64(s, 8))
            t.contextTokens = Int(sqlite3_column_int64(s, 9))
            out.append(t)
        }
        return out
    }

    public func deleteAgentTasks() throws { try run("DELETE FROM agent_tasks", []) }

    /// What was held back in a range, grouped by type (category), most first. Items that were later shown don't count.
    public func heldBack(from start: Date, to end: Date) throws -> [HeldGroup] {
        var out: [HeldGroup] = []
        try query("""
            SELECT category, kind, COUNT(DISTINCT item_id) AS n FROM decisions
            WHERE at >= ? AND at < ? AND item_id NOT IN
              (SELECT item_id FROM decisions WHERE outcome = 'shown' AND final_level >= 1 AND at >= ? AND at < ?)
            GROUP BY category, kind ORDER BY n DESC
            """, [start.timeIntervalSince1970, end.timeIntervalSince1970, start.timeIntervalSince1970, end.timeIntervalSince1970]) { s in
            out.append(HeldGroup(category: Self.text(s, 0) ?? "", kind: ItemKind(rawValue: Self.text(s, 1) ?? "") ?? .mail,
                                 count: Int(sqlite3_column_int64(s, 2))))
        }
        return out
    }

    // MARK: plumbing

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw StoreError.sqlite(msg)
        }
    }

    private func prepare(_ sql: String, _ args: [Any?]) throws -> OpaquePointer? {
        var s: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            switch a {
            case nil: sqlite3_bind_null(s, idx)
            case let v as Int: sqlite3_bind_int64(s, idx, Int64(v))
            case let v as Double: sqlite3_bind_double(s, idx, v)
            case let v as String: sqlite3_bind_text(s, idx, v, -1, Self.transient)
            default: sqlite3_bind_text(s, idx, String(describing: a!), -1, Self.transient)
            }
        }
        return s
    }

    private func run(_ sql: String, _ args: [Any?]) throws {
        let s = try prepare(sql, args)
        defer { sqlite3_finalize(s) }
        guard sqlite3_step(s) == SQLITE_DONE else { throw StoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
    }

    private func query(_ sql: String, _ args: [Any?], row: (OpaquePointer?) -> Void) throws {
        let s = try prepare(sql, args)
        defer { sqlite3_finalize(s) }
        while true {
            let rc = sqlite3_step(s)
            if rc == SQLITE_ROW { row(s); continue }
            if rc == SQLITE_DONE { return }
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func scalarInt(_ sql: String, _ args: [Any?]) throws -> Int {
        var v = 0
        try query(sql, args) { s in v = Int(sqlite3_column_int64(s, 0)) }
        return v
    }

    private static func text(_ s: OpaquePointer?, _ i: Int32) -> String? {
        sqlite3_column_text(s, i).map { String(cString: $0) }
    }
}

/// One kind of thing Hush held back ("12 from news@shop.com").
public struct HeldGroup: Sendable, Equatable {
    public var category: String
    public var kind: ItemKind
    public var count: Int

    /// "mail from news@shop.com", "agent updates in hush", "meeting reminders".
    public var label: String {
        if category == "meeting" { return "meeting reminders" }
        if category.hasPrefix("agent:") { return "agent updates in \(category.dropFirst(6))" }
        if category.hasPrefix("mail:") { return "mail from \(category.dropFirst(5))" }
        return category
    }
}

public struct DaySummary: Sendable, Equatable {
    public var shown: Int
    public var heldBack: Int

    public init(shown: Int, heldBack: Int) { self.shown = shown; self.heldBack = heldBack }

    /// The tuck-in card: "You got 4 things from me today. I held back 63."
    public var dayLine: String {
        if shown == 0 && heldBack == 0 { return "Quiet day. Nothing needed you." }
        return "You got \(Self.things(shown)) from me today. I held back \(heldBack)."
    }

    /// Friday's tuck-in: the week's count.
    public var weekLine: String {
        if shown == 0 && heldBack == 0 { return "Quiet week. Nothing needed you." }
        return "This week you got \(Self.things(shown)) from me. I held back \(heldBack)."
    }

    static func things(_ n: Int) -> String { n == 1 ? "1 thing" : "\(n) things" }
}

public struct LoggedDecision: Sendable, Equatable {
    public var id: String
    public var at: Date
    public var category: String
    public var finalLevel: AttentionLevel?
    public var outcome: Decision.Outcome
    public var confidence: Double?
    public var modelVersion: String?
    public var reasons: String
    public var response: UserResponse?
}
