import Foundation
import HushCore

/// The app's end of the browser-task gate: a unix socket only this user can open (0600, in Application Support),
/// one request per connection. Each run registers a fresh token; requests with any other token are refused.
public final class GateServer: @unchecked Sendable {
    public typealias Handler = @Sendable (GateRequest, @escaping @Sendable (Bool) -> Void) -> Void

    public let path: String
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?
    private let lock = NSLock()
    private var token: String?
    private var handler: Handler?
    private let queue = DispatchQueue(label: "dev.hush.gate", qos: .userInitiated)

    public init(path: String) { self.path = path }

    /// Start listening (idempotent). False if the socket can't be created.
    @discardableResult
    public func start() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if fd >= 0 { return true }
        unlink(path)
        let s = socket(AF_UNIX, SOCK_STREAM, 0)
        guard s >= 0 else { return false }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { close(s); return false }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, b) in bytes.enumerated() { buf[i] = b }
            buf[bytes.count] = 0
        }
        let old = umask(0o077)   // the socket file is created 0600
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        umask(old)
        guard bound == 0, chmod(path, 0o600) == 0, listen(s, 4) == 0 else { close(s); return false }
        fd = s
        let src = DispatchSource.makeReadSource(fileDescriptor: s, queue: queue)
        src.setEventHandler { [weak self] in self?.accept() }
        src.resume()
        source = src
        return true
    }

    /// The current run's token and who answers it. nil token: refuse everything.
    public func expect(token: String?, handler: Handler?) {
        lock.lock(); self.token = token; self.handler = handler; lock.unlock()
    }

    private func accept() {
        let c = Darwin.accept(fd, nil, nil)
        guard c >= 0 else { return }
        // Read one line, off the accept queue so a slow client can't block others.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var tv = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            var data = Data()
            var buf = [UInt8](repeating: 0, count: 1024)
            while !data.contains(0x0A), data.count < 8192 {
                let n = read(c, &buf, buf.count)
                if n <= 0 { break }
                data.append(contentsOf: buf[0..<n])
            }
            let reply: @Sendable (Bool) -> Void = { ok in
                var out = (try? JSONEncoder().encode(GateReply(ok: ok))) ?? Data()
                out.append(0x0A)
                _ = out.withUnsafeBytes { write(c, $0.baseAddress, out.count) }
                close(c)
            }
            guard let self, let req = try? JSONDecoder().decode(GateRequest.self, from: data.prefix { $0 != 0x0A }) else {
                reply(false); return
            }
            self.lock.lock(); let token = self.token; let handler = self.handler; self.lock.unlock()
            guard let token, req.token == token, let handler else { reply(false); return }
            // Answer once, whatever the handler does.
            let once = Once()
            handler(req) { ok in if once.claim() { reply(ok) } }
        }
    }

    private final class Once: @unchecked Sendable {
        private var done = false
        private let lock = NSLock()
        func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
    }
}
