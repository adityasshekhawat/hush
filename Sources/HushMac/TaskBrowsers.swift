import AppKit
import HushCore

/// What's on this Mac for browser tasks: which browsers have the Claude extension, which are running, and the
/// connection manifest each one needs (docs/lanes-plan.md § L3, Comet).
public enum TaskBrowsers {
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

    /// Installed browsers with the Claude extension in any profile.
    public static func withExtension() -> Set<TaskBrowser> {
        Set(TaskBrowser.allCases.filter { b in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: b.bundleID) != nil else { return false }
            let root = support.appendingPathComponent(b.dataFolder)
            let profiles = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
            return profiles.filter { $0 == "Default" || $0.hasPrefix("Profile ") }.contains { p in
                FileManager.default.fileExists(atPath: root.appendingPathComponent("\(p)/Extensions/\(TaskBrowser.extensionID)").path)
            }
        })
    }

    public static func running() -> Set<TaskBrowser> {
        Set(TaskBrowser.allCases.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).isEmpty })
    }

    /// Claude Code installs the manifest for some browsers only (not Comet). Copy it from one it did install, so the
    /// extension can reach Claude Code. Returns true if the manifest is in place.
    @discardableResult
    @MainActor public static func ensureManifest(for browser: TaskBrowser) -> Bool {
        let fm = FileManager.default
        let dir = support.appendingPathComponent(browser.dataFolder).appendingPathComponent("NativeMessagingHosts")
        let target = dir.appendingPathComponent(TaskBrowser.hostManifest)
        if fm.fileExists(atPath: target.path) { return true }
        guard let source = TaskBrowser.allCases.lazy
            .map({ support.appendingPathComponent($0.dataFolder).appendingPathComponent("NativeMessagingHosts/\(TaskBrowser.hostManifest)") })
            .first(where: { fm.fileExists(atPath: $0.path) }),
              let data = fm.contents(atPath: source.path),
              // Only ever copy Claude Code's own manifest: the right host name and the Claude extension as its only caller.
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["name"] as? String == "com.anthropic.claude_code_browser_extension",
              json["allowed_origins"] as? [String] == ["chrome-extension://\(TaskBrowser.extensionID)/"] else { return false }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let ok = fm.createFile(atPath: target.path, contents: data, attributes: [.posixPermissions: 0o644])
        DiagnosticsLog.write("browser: \(ok ? "added" : "couldn't add") the Claude Code connection for \(browser.displayName)")
        return ok
    }
}
