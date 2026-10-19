import Foundation
import HushMac
import ServiceManagement

/// "Open at login" through macOS's login-item service; it appears in System Settings → General → Login Items,
/// where you can also turn it off.
@MainActor
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    /// macOS may need you to approve it in System Settings the first time.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            DiagnosticsLog.write("login item: \(on ? "on" : "off") (status \(SMAppService.mainApp.status.rawValue))")
        } catch {
            DiagnosticsLog.write("login item: \(on ? "register" : "unregister") failed: \(error.localizedDescription)")
            if needsApproval { SMAppService.openSystemSettingsLoginItems() }
        }
    }
}
