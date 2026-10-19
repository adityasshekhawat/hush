import Foundation
import HushCore

/// Receives status events from `hushctl` (Claude Code hooks). A narrow, validated channel: status only. Any local
/// process can post a distributed notification, so nothing here can ever start a task or run a command.
@MainActor
public final class AgentStatusReceiver {
    public static let channel = Notification.Name("dev.hush.agent-status")   // must match hushctl

    public var onEvent: ((AgentSessionEvent) -> Void)?
    private var observer: NSObjectProtocol?
    private var recent: [Date] = []

    public init() {}

    public func start() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(forName: Self.channel, object: nil, queue: .main) { [weak self] n in
            let info = n.userInfo as? [String: String] ?? [:]
            MainActor.assumeIsolated { self?.receive(info) }
        }
    }

    public func stop() {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        observer = nil
    }

    func receive(_ info: [String: String]) {
        guard let e = Self.validate(info, at: Date()) else {
            DiagnosticsLog.write("agent: rejected status event \(info.keys.sorted())")
            return
        }
        // Rate limit: a misbehaving sender shouldn't be able to keep Hush busy.
        let now = Date()
        recent = recent.filter { now.timeIntervalSince($0) < 1 } + [now]
        guard recent.count <= 40 else { return }
        onEvent?(e)
    }

    /// Exactly the expected keys and shapes, or nothing.
    nonisolated static func validate(_ info: [String: String], at now: Date) -> AgentSessionEvent? {
        let allowed: Set<String> = ["v", "event", "session", "cwd", "app", "agent", "tty"]
        guard Set(info.keys).isSubset(of: allowed), info["v"] == "1",
              let kindRaw = info["event"], let kind = AgentSessionEvent.Kind(rawValue: kindRaw),
              let session = info["session"], session.range(of: #"^[A-Za-z0-9-]{8,64}$"#, options: .regularExpression) != nil,
              let cwd = info["cwd"], cwd.hasPrefix("/"), cwd.count < 1024, !cwd.contains("\0") else { return nil }
        var app: String?
        if let a = info["app"] {
            guard a.range(of: #"^[A-Za-z0-9.\-]{3,128}$"#, options: .regularExpression) != nil else { return nil }
            app = a
        }
        var agent = AgentKind.claude
        if let a = info["agent"] {
            guard let k = AgentKind(rawValue: a) else { return nil }
            agent = k
        }
        var tty: String?
        if let t = info["tty"] {
            guard t.range(of: #"^/dev/ttys[0-9]{1,4}$"#, options: .regularExpression) != nil else { return nil }
            tty = t
        }
        return AgentSessionEvent(sessionID: session, cwd: cwd, kind: kind, app: app, at: now, agent: agent, tty: tty)
    }
}
