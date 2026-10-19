import Foundation
import HushCore

/// Receives status events from `hushctl` (Claude Code and Codex hooks) over a private Unix socket (ADR-024): 0600 in
/// Hush's Application Support folder, so only this user's processes can connect, and nothing is broadcast to other
/// apps the way a distributed notification is. Status only: nothing here can start a task or run a command. Every
/// event is validated (`AgentChannel`) and rate-limited.
@MainActor
public final class AgentStatusReceiver {
    public var onEvent: ((AgentSessionEvent) -> Void)?
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?
    private var recent: [Date] = []
    private let queue = DispatchQueue(label: "dev.hush.agent-status")

    public init() {}

    public func start() {
        guard fd < 0 else { return }
        let path = AgentChannel.socketPath
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        unlink(path)
        let s = socket(AF_UNIX, SOCK_STREAM, 0)
        guard s >= 0 else { DiagnosticsLog.write("agent: couldn't open the socket"); return }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            close(s)
            DiagnosticsLog.write("agent: socket path too long")
            return
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, b) in bytes.enumerated() { buf[i] = b }
            buf[bytes.count] = 0
        }
        let old = umask(0o077)   // created 0600
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        umask(old)
        guard bound == 0, chmod(path, 0o600) == 0, listen(s, 16) == 0 else {
            close(s)
            DiagnosticsLog.write("agent: couldn't listen on the socket")
            return
        }
        fd = s
        let src = DispatchSource.makeReadSource(fileDescriptor: s, queue: queue)
        let deliver: @Sendable ([String: String]) -> Void = { [weak self] info in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receive(info) } }
        }
        src.setEventHandler(handler: Self.acceptHandler(listening: s, deliver: deliver))
        src.resume()
        source = src
    }

    public func stop() {
        source?.cancel()
        source = nil
        if fd >= 0 { close(fd); fd = -1 }
        unlink(AgentChannel.socketPath)
    }

    func receive(_ info: [String: String]) {
        guard let e = AgentChannel.event(from: info, at: Date()) else {
            DiagnosticsLog.write("agent: rejected status event \(info.keys.sorted())")
            return
        }
        // Rate limit: a misbehaving sender shouldn't be able to keep Hush busy.
        let now = Date()
        recent = recent.filter { now.timeIntervalSince($0) < 1 } + [now]
        guard recent.count <= 40 else { return }
        onEvent?(e)
    }

    /// Runs on the socket's queue, so it's built outside the main actor: a closure written inside this @MainActor class
    /// would be main-actor isolated, and Swift stops the app when it runs anywhere else (it did, on the first event).
    nonisolated private static func acceptHandler(listening s: Int32, deliver: @escaping @Sendable ([String: String]) -> Void)
        -> @Sendable () -> Void {
        return {
            let c = accept(s, nil, nil)
            guard c >= 0 else { return }
            let line = readLine(c)
            close(c)
            guard let line, let info = (try? JSONSerialization.jsonObject(with: line)) as? [String: String] else { return }
            deliver(info)
        }
    }

    /// One newline-terminated line, at most 4 KB, within a second.
    nonisolated private static func readLine(_ c: Int32) -> Data? {
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 1024)
        while !data.contains(0x0A), data.count < 4096 {
            let n = read(c, &buf, buf.count)
            if n <= 0 { break }
            data.append(contentsOf: buf[0..<n])
        }
        guard let end = data.firstIndex(of: 0x0A) else { return nil }
        return data[..<end]
    }
}
