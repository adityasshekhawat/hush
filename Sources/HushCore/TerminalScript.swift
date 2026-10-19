import Foundation

/// AppleScript that types a message into the terminal tab a session runs in (found by its tty), for Terminal and
/// iTerm. Other terminals can't be scripted; the app copies the message and brings them forward instead.
public enum TerminalScript {
    public static let terminal = "com.apple.Terminal"
    public static let iterm = "com.googlecode.iterm2"

    public static func canType(into bundleID: String?) -> Bool { bundleID == terminal || bundleID == iterm }

    /// One line (a newline would submit early), quoted for AppleScript.
    public static func quote(_ text: String) -> String {
        let oneLine = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        return "\"" + oneLine.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Selects the tab a session runs in and brings its window forward (ADR-024): "Open" lands on the exact tab, not
    /// just the app. nil if this app can't be scripted or the tty doesn't look like one.
    public static func focusSource(bundleID: String?, tty: String?) -> String? {
        guard let tty, tty.range(of: #"^/dev/ttys[0-9]{1,4}$"#, options: .regularExpression) != nil else { return nil }
        let dev = quote(tty)
        switch bundleID {
        case terminal:
            return """
            tell application id "\(terminal)"
              repeat with w in windows
                repeat with t in tabs of w
                  if tty of t is \(dev) then
                    set selected of t to true
                    set index of w to 1
                    activate
                    return "focused"
                  end if
                end repeat
              end repeat
            end tell
            return "not found"
            """
        case iterm:
            return """
            tell application id "\(iterm)"
              repeat with w in windows
                repeat with t in tabs of w
                  repeat with s in sessions of t
                    if tty of s is \(dev) then
                      select w
                      tell t to select
                      tell s to select
                      activate
                      return "focused"
                    end if
                  end repeat
                end repeat
              end repeat
            end tell
            return "not found"
            """
        default:
            return nil
        }
    }

    /// nil if this app can't be scripted or the tty doesn't look like one.
    public static func source(bundleID: String?, tty: String?, text: String) -> String? {
        guard let tty, tty.range(of: #"^/dev/ttys[0-9]{1,4}$"#, options: .regularExpression) != nil else { return nil }
        let msg = quote(text), dev = quote(tty)
        switch bundleID {
        case terminal:
            return """
            tell application id "\(terminal)"
              repeat with w in windows
                repeat with t in tabs of w
                  if tty of t is \(dev) then
                    do script \(msg) in t
                    return "sent"
                  end if
                end repeat
              end repeat
            end tell
            return "not found"
            """
        case iterm:
            return """
            tell application id "\(iterm)"
              repeat with w in windows
                repeat with t in tabs of w
                  repeat with s in sessions of t
                    if tty of s is \(dev) then
                      tell s to write text \(msg)
                      return "sent"
                    end if
                  end repeat
                end repeat
              end repeat
            end tell
            return "not found"
            """
        default:
            return nil
        }
    }
}
