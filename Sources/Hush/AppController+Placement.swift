import AppKit
import HushCore
import HushMac
import SwiftUI

/// Where Hush sits: the home spot along the bottom edge and coordinate helpers.
extension AppController {
    func placeAtHome(animated: Bool = false) {
        if wanderer?.isAway == true { return }
        let frame = homeFrame()
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    /// The drawn character in screen coordinates (bottom-left origin).
    /// Keep every open card clear of Hush (docs: CardPlacement — never cover Hush).
    /// The area cards must stay out of: Hush as drawn, plus the room it pops up into when you hover a peeking Hush
    /// (it rises ~34 pt), so a card never has to dodge after the fact.
    func cardAvoidRect() -> NSRect {
        var r = characterRectScreen()
        // While hovered, the reported outline already includes the rise; don't count it twice.
        if !hovered, currentState == .peek || (currentState == .hide && currentDuck) {
            r.size.height += Self.peekRise
        }
        return r
    }

    /// How far a peeking Hush rises when you hover it (renderer: `#hush.risen #rise`, 34 view units).
    static let peekRise: CGFloat = 36

    func relayoutCards() {
        let r = cardAvoidRect()
        if UserDefaults.standard.bool(forKey: "HushDebugHooks") {
            DiagnosticsLog.write("place: character \(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)) (view bounds \(characterBounds.integral)) panel \(panel.frame.integral)")
        }
        onboarding?.reposition()
        ask?.card.relayout(avoiding: r)
        envelope.relayout(avoiding: r)
        rulesCard.relayout(avoiding: r)
        heldBack.relayout(avoiding: r)
        ask?.browser.pill.relayout(beside: r)
        digest?.relayout(avoiding: r)
        if commandPanel.isOpen { commandPanel.relayout(avoiding: r) }
        tipBubble.relayout(avoiding: r)
        bubble.relayout(avoiding: r)
        pouch?.relayout()
    }

    func characterRectScreen() -> NSRect {
        let f = panel.frame
        let b = characterBounds.isEmpty ? CGRect(origin: .zero, size: f.size) : characterBounds
        return NSRect(x: f.minX + b.minX, y: f.maxY - b.maxY, width: b.width, height: b.height)
    }

    /// The same, in CoreGraphics global coordinates (top-left origin), as CGWindowList reports windows.
    func characterRectCG() -> CGRect {
        let r = characterRectScreen()
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

    func homeFrame() -> NSRect {
        guard let vf = screen?.visibleFrame else { return panel.frame }
        let size = panel.frame.size
        // The page's bottom 34/146 of the art height sits below the floor (see renderer/compose.js, refresh).
        let artHeight = renderer.characterHeight * 146 / 100
        return NSRect(origin: NSPoint(x: vf.minX + homeX * (vf.width - size.width), y: vf.minY - artHeight * 34 / 146),
                      size: size)
    }

    func flipped(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: gestureView.bounds.height - r.maxY, width: r.width, height: r.height)
    }

    /// The held-back card (design guide §5.2).
    func showHeldBack(_ kind: HeldBackModel.Kind, list: Bool = false, demo: Bool = false) {
        heldBack.engine = engine
        heldBack.onWhatILearned = { [weak self] in self?.showRules() }
        heldBack.vips = { [weak self] in self?.settings.vips ?? [] }
        heldBack.show(kind, avoiding: cardAvoidRect(), list: list, demo: demo)
        if kind == .week { renderer.react(.proud) }
    }

    /// What I've learned (design guide §5.3).
    func showRules() {
        rulesCard.engine = engine
        rulesCard.triage = triage
        rulesCard.react = { [weak self] r in self?.renderer.react(r) }
        rulesCard.show(avoiding: cardAvoidRect())
    }

    // MARK: settings
}
