import AppKit
import HushCore
import HushMac

/// Adds Hush's hooks to ~/.claude/settings.json or ~/.codex/hooks.json (merged next to whatever is there), and takes
/// them out again. Always shows the exact change and asks first; keeps a timestamped backup next to the file.
@MainActor
enum HookInstaller {
    static func settingsURL(_ agent: AgentKind) -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(agent == .claude ? ".claude/settings.json" : ".codex/hooks.json")
    }

    /// Codex is set up on this Mac (its folder exists), so offering to watch it makes sense.
    static var codexPresent: Bool {
        FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path)
    }

    /// hushctl inside the running app bundle (or next to the binary during development).
    static var hushctlPath: String {
        let inBundle = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/hushctl").path
        if FileManager.default.isExecutableFile(atPath: inBundle) { return inBundle }
        return Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("hushctl").path
    }

    static func load(_ agent: AgentKind = .claude) throws -> [String: Any] {
        let url = settingsURL(agent)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Hush", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(url.lastPathComponent) isn't a JSON object"])
        }
        return obj
    }

    static var isInstalled: Bool { isInstalled(.claude) }
    static func isInstalled(_ agent: AgentKind) -> Bool { (try? load(agent)).map(ClaudeHooksConfig.isInstalled(in:)) ?? false }

    static func pretty(_ obj: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return "" }
        return String(decoding: d, as: UTF8.self)
    }

    /// Line diff (old → new) of the pretty-printed JSON, for the confirmation sheet.
    static func diff(_ old: [String: Any], _ new: [String: Any]) -> String {
        let a = pretty(old).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let b = pretty(new).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let changes = b.difference(from: a)
        var removed = Set<Int>(), inserted = Set<Int>()
        for c in changes {
            switch c {
            case .remove(let o, _, _): removed.insert(o)
            case .insert(let o, _, _): inserted.insert(o)
            }
        }
        // Walk both sides and print a compact unified view with 1 line of context.
        var out: [String] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count, removed.contains(i) { out.append("- " + a[i]); i += 1; continue }
            if j < b.count, inserted.contains(j) { out.append("+ " + b[j]); j += 1; continue }
            if i < a.count { out.append("  " + a[i]) }
            i += 1; j += 1
        }
        // Trim long unchanged stretches.
        var trimmed: [String] = []
        for (k, line) in out.enumerated() {
            let near = (max(0, k - 1)...min(out.count - 1, k + 1)).contains { !out[$0].hasPrefix("  ") }
            if near || !line.hasPrefix("  ") { trimmed.append(line) }
            else if trimmed.last != "  …" { trimmed.append("  …") }
        }
        return trimmed.joined(separator: "\n")
    }

    /// If Hush's hooks point at another copy of Hush (it moved, or was reinstalled to /Applications), point them
    /// here. Same hooks you approved; only the path changes. Backup kept, change logged.
    static func migratePath() {
        for agent in AgentKind.allCases {
            guard let old = try? load(agent), let new = ClaudeHooksConfig.repointed(old, hushctl: hushctlPath) else { continue }
            do {
                try write(new, agent)
                DiagnosticsLog.write("hooks: \(agent.rawValue) repointed to \(hushctlPath)")
            } catch {
                DiagnosticsLog.write("hooks: couldn't repoint \(agent.rawValue): \(error.localizedDescription)")
            }
        }
    }

    static func install(_ agent: AgentKind = .claude) { change(installing: true, agent) }
    static func uninstall(_ agent: AgentKind = .claude) { change(installing: false, agent) }

    private static func change(installing: Bool, _ agent: AgentKind) {
        DiagnosticsLog.write("hooks: \(agent.rawValue) \(installing ? "install" : "uninstall") requested")
        do {
            let old = try load(agent)
            let new = installing ? ClaudeHooksConfig.install(into: old, hushctl: hushctlPath, agent: agent) : ClaudeHooksConfig.uninstall(from: old)
            let text = diff(old, new)
            guard confirm(installing: installing, agent, diff: text) else {
                DiagnosticsLog.write("hooks: cancelled, nothing written")
                return
            }
            try write(new, agent)
            DiagnosticsLog.write("hooks: \(agent.rawValue) \(installing ? "installed" : "removed") in \(settingsURL(agent).path)")
        } catch {
            DiagnosticsLog.write("hooks: failed: \(error.localizedDescription)")
            let a = NSAlert(error: error)
            a.window.level = .modalPanel
            a.runModal()
        }
    }

    private static func write(_ obj: [String: Any], _ agent: AgentKind = .claude) throws {
        let fm = FileManager.default
        let url = settingsURL(agent)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: url.path) {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            try fm.copyItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).hush-backup-\(stamp)"))
        }
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }

    private static func confirm(installing: Bool, _ agent: AgentKind, diff: String) -> Bool {
        let alert = NSAlert()
        let name = agent.senderName
        let file = agent == .claude ? "~/.claude/settings.json" : "~/.codex/hooks.json"
        alert.messageText = installing ? "Let Hush watch your \(name) sessions?" : "Remove Hush's \(name) hooks?"
        alert.informativeText = installing
            ? "This adds small hooks to \(file), next to any already there. They only tell Hush that a session started, is working, needs you, or finished: never your prompts, the agent's replies or your code. A backup of the current file is kept beside it."
                + (agent == .codex ? " Codex runs new hooks only after you trust them: open Codex and run /hooks once." : "")
                + "\n\nThe change:"
            : "Only Hush's own entries are removed; everything else stays. A backup is kept beside the file.\n\nThe change:"
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 260))
        scroll.hasVerticalScroller = true
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let styled = NSMutableAttributedString()
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            let color: NSColor = line.hasPrefix("+") ? .systemGreen : line.hasPrefix("-") ? .systemRed : .secondaryLabelColor
            styled.append(NSAttributedString(string: line + "\n", attributes: [.foregroundColor: color, .font: tv.font!]))
        }
        tv.textStorage?.setAttributedString(styled)
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        alert.accessoryView = scroll
        alert.addButton(withTitle: installing ? "Add hooks" : "Remove hooks")
        alert.addButton(withTitle: "Cancel")
        // A menu bar app's alert can open behind other apps' windows: float it and bring it forward.
        NSApp.activate()
        alert.window.level = .modalPanel
        alert.window.orderFrontRegardless()
        return alert.runModal() == .alertFirstButtonReturn
    }
}
