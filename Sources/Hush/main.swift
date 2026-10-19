import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private var menuBar: MenuBar?
    /// App Nap would slow Hush's timers to ~1 Hz in the background: jerky eyes, missed ⌘V. Hush is always "visible".
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Hush is on screen and reacting to the pointer")
        do {
            let c = try AppController()
            c.start()
            controller = c
            menuBar = MenuBar(app: c)
        } catch {
            NSLog("Hush failed to start: \(error)")
            NSApp.terminate(nil)
        }
    }
}

/// Text fields get ⌘X/⌘C/⌘V/⌘A/⌘Z through the Edit menu's key equivalents. A menu bar app has no menu bar, so
/// without this menu those shortcuts do nothing in Ask Hush, Settings or onboarding. It's never shown.
@MainActor
func installEditMenu() {
    let main = NSMenu()
    let editItem = NSMenuItem()
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    edit.addItem(.separator())
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = edit
    main.addItem(editItem)
    NSApp.mainMenu = main
}

let app = NSApplication.shared
// Menu bar app: no Dock icon, never takes over the screen (LSUIElement does the same when bundled).
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
