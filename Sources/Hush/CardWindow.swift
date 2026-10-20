import AppKit
import HushCore
import SwiftUI

/// One floating card (docs/design-guide.md §2–4): material, 16 pt continuous corners, a 0.5 pt hairline and the
/// guide's shadow (0 12 32 at 18 %), a spring in from Hush and a sink back toward it, and placement that never
/// covers Hush. Non-activating: it takes focus only when `keyable` and you click into a field.
@MainActor
final class CardWindow {
    /// Transparent room around the card for its shadow.
    static let margin: CGFloat = 36

    let presence = CardPresence()
    private let panel: NSPanel
    private var hosting: NSHostingView<AnyView>!
    let width: CGFloat
    var maxHeight: CGFloat
    private var avoid: NSRect = .zero
    /// When set and returning a frame, the card stacks 8 pt above it (the command box over an answer card).
    var stackAbove: (() -> NSRect?)?
    private var closing = false

    init(width: CGFloat, maxHeight: CGFloat = 520, keyable: Bool = false, padded: Bool = true,
         @ViewBuilder content: () -> some View) {
        self.width = width
        self.maxHeight = maxHeight
        let p: NSPanel = keyable
            ? KeyableCardPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
            : NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false   // drawn by SwiftUI, to the guide's spec
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        panel = p
        let root = CardChrome(presence: presence, width: width, padded: padded, content: content())
        hosting = NSHostingView(rootView: AnyView(root))
        hosting.frame = NSRect(x: 0, y: 0, width: width + 2 * Self.margin, height: 200)
        p.contentView = hosting
    }

    var window: NSPanel { panel }
    var isOpen: Bool { panel.isVisible && !closing }
    /// The card itself on screen (without the shadow margin).
    var frame: NSRect? { isOpen ? panel.frame.insetBy(dx: Self.margin, dy: Self.margin) : nil }

    func show(avoiding character: NSRect, makeKey: Bool = false) {
        avoid = character
        closing = false
        let appearing = !panel.isVisible
        if appearing { presence.shown = false }
        place(animated: false)
        makeKey ? panel.makeKeyAndOrderFront(nil) : panel.orderFrontRegardless()
        if appearing {
            DispatchQueue.main.async { withAnimation(HushMotion.cardIn) { self.presence.shown = true } }
        }
    }

    /// Re-fit to the content (call after it changes size).
    func resize() { if panel.isVisible { place(animated: true) } }

    /// Hush moved or changed pose: keep clear of it, following with the card spring.
    func relayout(avoiding character: NSRect) {
        avoid = character
        if panel.isVisible { place(animated: true) }
    }

    func close(completion: (() -> Void)? = nil) {
        guard panel.isVisible, !closing else { completion?(); return }
        closing = true
        withAnimation(HushMotion.cardOut) { presence.shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.closing else { return }
            self.panel.orderOut(nil)
            self.closing = false
            completion?()
        }
    }

    private func place(animated: Bool) {
        let fit = hosting.fittingSize
        let card = NSSize(width: width, height: min(maxHeight, max(40, fit.height - 2 * Self.margin)))
        let vf = NSScreen.main?.visibleFrame ?? .zero
        let cardFrame: CGRect
        if let below = stackAbove?() {
            cardFrame = CardPlacement.frame(size: card, stackedAbove: below, in: vf)
        } else {
            cardFrame = CardPlacement.frame(size: card, avoiding: avoid, in: vf)
        }
        // The spring grows from Hush: anchor the scale at Hush's side of the card.
        presence.anchor = UnitPoint(x: min(1, max(0, (avoid.midX - cardFrame.minX) / cardFrame.width)),
                                    y: min(1, max(0, (cardFrame.maxY - avoid.midY) / cardFrame.height)))
        let target = cardFrame.insetBy(dx: -Self.margin, dy: -Self.margin)
        if animated, !HushMotion.reduceMotion, panel.frame != target {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }
}

final class CardPresence: ObservableObject {
    @Published var shown = false
    @Published var anchor: UnitPoint = .bottom
}

/// The card's look and its appear/dismiss motion.
struct CardChrome<Content: View>: View {
    @ObservedObject var presence: CardPresence
    let width: CGFloat
    let padded: Bool
    let content: Content

    var body: some View {
        content
            .padding(.horizontal, padded ? HushSpace.cardH : 0)
            .padding(.vertical, padded ? HushSpace.cardV : 0)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: HushSpace.cardRadius, style: .continuous))
            .hushSurface(radius: HushSpace.cardRadius)
            .scaleEffect(presence.shown || HushMotion.reduceMotion ? 1 : 0.96, anchor: presence.anchor)
            .offset(y: presence.shown || HushMotion.reduceMotion ? 0 : 6)
            .opacity(presence.shown ? 1 : 0)
            .padding(CardWindow.margin)
    }
}

private final class KeyableCardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
