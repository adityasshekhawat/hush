import AppKit
import Carbon.HIToolbox
import HushCore
import HushMac
import Combine
import SwiftUI

/// The command box (⌘⇧H). Unlike the overlay, this panel *can* take typing. It remembers which app you were in,
/// shows where your question will go before you press Enter, and hands focus straight back when it closes.
@MainActor
final class CommandPanel: NSObject, NSWindowDelegate {
    let model = CommandBoxModel()
    private let panel: NSPanel
    private var previousApp: NSRunningApplication?
    /// Called with the question, the lane it should take, and the thread it follows up on (if any).
    var onSubmit: ((String, AskLane, FollowUp?, Bool) -> Void)?
    /// Called with a phrasing and the lane you corrected it to.
    var onCorrection: ((String, LaneKind) -> Void)?
    var learnedRoutes: () -> LearnedRoutes = { LearnedRoutes() }
    var onClose: (() -> Void)?
    var onAddRepo: (() -> Void)?

    /// Field (46) + hint line; grows upward when the route menu opens. The extra margin is for the shadow.
    static let shadowMargin: CGFloat = 24
    private var size: NSSize {
        let fit = (panel.contentView as? NSHostingView<CommandBoxView>)?.fittingSize ?? NSSize(width: 420, height: 70)
        return NSSize(width: CommandBoxView.width + 2 * Self.shadowMargin, height: fit.height)
    }
    var onCarryOn: (() -> Void)?
    /// The pose Hush holds while the box is open, for the route it shows (nil when it closes).
    var onPose: ((String?) -> Void)?
    private var laneObserver: Any?
    private var menuObserver: Any?

    override init() {
        panel = KeyablePanel(contentRect: NSRect(origin: .zero, size: NSSize(width: 468, height: 120)),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Drawn by SwiftUI (field and route menu), like the cards. A window shadow here traces the soft SwiftUI shadow's
        // pixels and shows as a jagged dark ring around the box.
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: CommandBoxView(model: model, actions: .init(
            submit: { [weak self] in self?.submit() },
            cancel: { [weak self] in self?.close() },
            addRepo: { [weak self] in
                self?.close(restoreFocus: false)
                self?.onAddRepo?()
            },
            carryOn: { [weak self] in
                self?.close()
                self?.onCarryOn?()
            })))
        laneObserver = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.updatePose() } }
        }
        menuObserver = model.$menuOpen.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.relayout(avoiding: self?.lastAvoid ?? .zero) } }
        }
        // Another app took focus (you switched away, or something activated itself): put the box away.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close(restoreFocus: false) }
        }
    }

    var isOpen: Bool { panel.isVisible }

    /// Opens just above `anchor` (Hush's on-screen rect), taking keyboard focus.
    func open(above anchor: NSRect, followUp: FollowUp? = nil, context: (String?) -> AskContext) {
        if panel.isVisible { panel.makeKey(); return }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        model.context = context(previousApp?.bundleIdentifier)
        model.learned = learnedRoutes()
        model.reset()
        model.followUp = followUp
        relayout(avoiding: anchor)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.updatePose() }   // after the command-window sequence
        DiagnosticsLog.write("command: opened (previous app: \(previousApp?.bundleIdentifier ?? "none"))")
        // macOS only lets an app come forward in response to something you did (a real hotkey press counts;
        // a script doesn't). If activation was refused, typing would land in the other app, so don't linger.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.panel.isVisible else { return }
            if NSApp.isActive {
                DiagnosticsLog.write("command: has focus")
            } else if !self.keepOpenForPreview {
                DiagnosticsLog.write("command: macOS didn't give Hush focus; closing")
                self.close(restoreFocus: false)
            }
        }
    }

    /// Debug/preview: keep the box open even without focus (scripted opens can't take focus).
    var keepOpenForPreview = false

    private func submit() {
        let q = model.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let lane = model.lane
        // An explicit @prefix or a lane you picked still counts as a follow-up: the context goes along.
        let followUp = model.followUp
        let check = model.needsCheck
        if let fix = model.correction, !q.isEmpty { onCorrection?(q, fix) }
        close()
        if !q.isEmpty { onSubmit?(q, lane, followUp, check) }
    }

    /// The answer card's frame, kept clear while following up on it (so the answer stays readable).
    var answerCardFrame: () -> NSRect? = { nil }

    /// Keep clear of Hush (opening, or when Hush changes pose underneath the box), and of the card when following up.
    private var lastAvoid: NSRect = .zero
    private var shownPose: String?

    private func updatePose() {
        guard panel.isVisible else { return }
        let pose: String
        switch model.lane {
        case .repo: pose = "sitThink"
        case .handoff: pose = "sitPoint"
        default: pose = "sitListen"
        }
        if pose != shownPose { shownPose = pose; onPose?(pose) }
    }

    func relayout(avoiding character: NSRect) {
        lastAvoid = character
        let vf = NSScreen.main?.visibleFrame ?? .zero
        let m = Self.shadowMargin
        let inner = NSSize(width: size.width - 2 * m, height: size.height - 2 * m)
        // Follow-up: stack 8 pt above the answer card; otherwise sit where a card would.
        let frame = model.followUp != nil && answerCardFrame() != nil
            ? CardPlacement.frame(size: inner, stackedAbove: answerCardFrame()!, in: vf)
            : CardPlacement.frame(size: inner, avoiding: character, in: vf)
        panel.setFrame(frame.insetBy(dx: -m, dy: -m), display: true)
    }

    func close(restoreFocus: Bool = true) {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        if restoreFocus, let app = previousApp { app.activate() }
        DiagnosticsLog.write("command: closed (\(restoreFocus ? "focus back to \(previousApp?.bundleIdentifier ?? "none")" : "focus already elsewhere"))")
        previousApp = nil
        keepOpenForPreview = false
        shownPose = nil
        onPose?(nil)
        onClose?()
    }

    // Clicking elsewhere dismisses it, without yanking focus back from wherever you clicked.
    func windowDidResignKey(_ notification: Notification) {
        if !keepOpenForPreview { close(restoreFocus: false) }
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
