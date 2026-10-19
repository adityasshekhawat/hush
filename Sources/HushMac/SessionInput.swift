import AppKit
import HushCore

/// Sends a message you typed to a running session: typed into its Terminal or iTerm tab (macOS asks once for
/// permission to control that app), otherwise copied with the app brought forward so you paste it.
public enum SessionInput {
    public enum Result: Equatable {
        case typed
        case copied(app: String)
        case failed(String)
    }

    /// "Open" on an agent card: the exact Terminal or iTerm tab when the session's tty is known (macOS asks once to let
    /// Hush control that app), otherwise just bring the app forward (Ghostty, Warp, Cursor, VS Code…). ADR-024.
    @MainActor
    @discardableResult
    public static func focus(bundleID: String?, tty: String?) -> Bool {
        if let src = TerminalScript.focusSource(bundleID: bundleID, tty: tty) {
            var error: NSDictionary?
            let out = NSAppleScript(source: src)?.executeAndReturnError(&error)
            if error == nil, out?.stringValue == "focused" {
                DiagnosticsLog.write("session focus: tab in \(bundleID ?? "?")")
                return true
            }
            DiagnosticsLog.write("session focus: \(error.map { "script failed (\($0[NSAppleScript.errorNumber] as? Int ?? 0))" } ?? "tab not found"); app instead")
        }
        guard let id = bundleID, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { return false }
        app.activate()
        return true
    }

    @MainActor
    public static func send(_ text: String, bundleID: String?, tty: String?) -> Result {
        if let src = TerminalScript.source(bundleID: bundleID, tty: tty, text: text) {
            var error: NSDictionary?
            let out = NSAppleScript(source: src)?.executeAndReturnError(&error)
            if let error {
                let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                DiagnosticsLog.write("session input: script failed (\(code))")
                // -1743: you said no to letting Hush control the app.
                return .failed(code == -1743
                    ? "Hush isn't allowed to control that app. Allow it in System Settings, Privacy and Security, Automation."
                    : "I couldn't type into that tab. It's copied instead.")
            }
            if out?.stringValue == "sent" { DiagnosticsLog.write("session input: typed into \(bundleID ?? "?")"); return .typed }
            DiagnosticsLog.write("session input: tab not found")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        PlaySensors.ownCopyChangeCount = NSPasteboard.general.changeCount
        let name = bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? "the terminal"
        if let id = bundleID, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first { app.activate() }
        DiagnosticsLog.write("session input: copied for \(name)")
        return .copied(app: name)
    }
}
