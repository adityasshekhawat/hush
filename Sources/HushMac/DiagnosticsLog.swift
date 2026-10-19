import Foundation

/// A tiny local text log for behaviour that's hard to see from outside (e.g. paste detection).
/// Timings and decisions only: never clipboard contents, never keys. Lives next to the decision log, capped.
public enum DiagnosticsLog {
    public static let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Hush/diagnostics.log")
    }()
    private static let maxLines = 400
    nonisolated(unsafe) private static var lines: [String] = {
        (try? String(contentsOf: url, encoding: .utf8))?.split(separator: "\n").suffix(maxLines).map(String.init) ?? []
    }()
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    @MainActor
    public static func write(_ message: String) {
        lines.append("\(stamp.string(from: Date())) \(message)")
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
