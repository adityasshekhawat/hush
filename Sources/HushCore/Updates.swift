import Foundation

/// New versions (ADR-036): Hush asks GitHub for the latest release only when you say so ("Check for updates…"), or
/// once a day if you agreed to that. The request carries nothing about you. Pure parts here; the request is in HushMac.
public enum Updates {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/adityasshekhawat/hush/releases/latest")!

    public struct Release: Sendable, Equatable {
        public var version: String
        public var page: URL
        public init(version: String, page: URL) { self.version = version; self.page = page }
    }

    /// GitHub's "latest release" answer, or nil if it isn't one (drafts and pre-releases don't count).
    public static func release(fromJSON data: Data) -> Release? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = o["tag_name"] as? String, let page = (o["html_url"] as? String).flatMap(URL.init(string:)),
              page.host == "github.com",
              (o["draft"] as? Bool) != true, (o["prerelease"] as? Bool) != true,
              let v = normalized(tag) else { return nil }
        return Release(version: v, page: page)
    }

    /// "v0.2.0" → "0.2.0"; nil for anything that isn't numbers and dots.
    public static func normalized(_ tag: String) -> String? {
        let v = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let parts = v.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        return v
    }

    /// Is `candidate` newer than `current`? Numeric, part by part ("0.10.0" > "0.9.3"); missing parts count as 0.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let c = normalized(candidate), let h = normalized(current) else { return false }
        let a = c.split(separator: ".").map { Int($0) ?? 0 }, b = h.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Daily checks only with your yes, and at most once in 20 hours (a check at launch and one a day after).
    public static func shouldCheck(consent: Bool?, lastCheck: Date?, now: Date) -> Bool {
        guard consent == true else { return false }
        guard let last = lastCheck else { return true }
        return now.timeIntervalSince(last) >= 20 * 3600 || now < last
    }

    /// The Terminal script behind "Update": your clone, pulled and rebuilt. `folder` is where you cloned Hush.
    public static func updateScript(folder: String) -> String {
        let q = "'" + folder.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return """
        #!/bin/sh
        # Updating Hush: pull the latest code into your clone, then build and reinstall it.
        cd \(q) || exit 1
        echo "Updating Hush in $(pwd)"
        git pull --ff-only && ./scripts/bundle.sh
        """
    }
}
