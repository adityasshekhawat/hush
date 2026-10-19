import AppKit
import Carbon.HIToolbox
import HushMac

/// A system-wide hotkey through Carbon's RegisterEventHotKey: works from any app with no Accessibility permission.
@MainActor
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private var id: UInt32 = 0

    /// Default ⌘⇧H (decided 2026-10-18).
    init?(keyCode: UInt32 = UInt32(kVK_ANSI_H), modifiers: UInt32 = UInt32(cmdKey | shiftKey), action: @escaping () -> Void) {
        self.action = action
        id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { MainActor.assumeIsolated { GlobalHotKey.actions[id]?() } }
            return noErr
        }, 1, &spec, nil, &handler)
        guard status == noErr else { return nil }
        let hkID = EventHotKeyID(signature: OSType(0x4855_5348), id: id)   // 'HUSH'
        let reg = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        guard reg == noErr else {
            DiagnosticsLog.write("hotkey: ⌘⇧H unavailable (status \(reg)); another app may have it")
            return nil
        }
    }

}
