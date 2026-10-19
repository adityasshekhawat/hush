import AppKit
import Carbon.HIToolbox
import HushMac

/// A system-wide hotkey through Carbon's RegisterEventHotKey: works from any app with no Accessibility permission.
@MainActor
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1

    /// Default ⌘⇧H (decided 2026-10-18). `name` is for the log, e.g. "⌥⇧⌘H".
    init?(keyCode: UInt32 = UInt32(kVK_ANSI_H), modifiers: UInt32 = UInt32(cmdKey | shiftKey), name: String = "⌘⇧H",
          action: @escaping () -> Void) {
        // One Carbon handler for every hotkey; it dispatches by id.
        if Self.handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hk)
                let id = hk.id
                DispatchQueue.main.async { MainActor.assumeIsolated { GlobalHotKey.actions[id]?() } }
                return noErr
            }, 1, &spec, nil, &Self.handler)
            guard status == noErr else {
                DiagnosticsLog.write("hotkey: couldn't install the handler (status \(status))")
                return nil
            }
        }
        let id = Self.nextID
        Self.nextID += 1
        let hkID = EventHotKeyID(signature: OSType(0x4855_5348), id: id)   // 'HUSH'
        let reg = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        guard reg == noErr else {
            DiagnosticsLog.write("hotkey: \(name) unavailable (status \(reg)); another app may have it")
            return nil
        }
        Self.actions[id] = action
    }
}
