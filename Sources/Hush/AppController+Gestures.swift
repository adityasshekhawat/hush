import AppKit
import HushCore
import HushMac
import SwiftUI

/// Mouse gestures on Hush: click, pat, shoo, drag and drop, and the envelope card.
extension AppController {
    func handle(_ g: GestureView.Gesture) {
        switch g {
        case .pressBegan:
            renderer.react(.press(true))
        case .patBegan:
            onboarding?.observed("pat")
            antics.touched()
            renderer.react(.pat(true))
        case .released:
            renderer.react(.press(false))
        case .click:
            antics.touched()
            if antics.cheeksFull && active == nil {
                // Clicking a full-cheeked Hush pops them.
                antics.emptyCheeks()
                return
            }
            if active != nil {
                showCard()
            } else if ambientPile > 0 {
                // Clicking the pile hands off to Mail and clears it.
                ambientPile = 0
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mail.app"))
                refresh()
            }
            renderer.react(.poke)
        case .shoo:
            envelope.close()
            if active != nil { resolveActive(.shooed) }
            if isLifted { dropToFloor() }
            justShooed = true
            refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                self?.justShooed = false
                self?.refresh()
            }
        case .dragBegan:
            dragPeakSpeed = 0
            wanderer.cancel()
            antics.touched()
            bubble.hide()
            isLifted = true
            envelope.close()
            renderer.react(.lift)
        case .drag(let dx, let dy, let vx):
            dragPeakSpeed = max(dragPeakSpeed, abs(vx))
            var f = panel.frame
            f.origin.x += dx
            f.origin.y += dy
            panel.setFrame(f, display: true)
            renderer.react(.swing(vx))
        case .dragEnded:
            rare?.dragged()
            onboarding?.observed("drag")
            // Dropped on a window's top edge: perch there (home spot unchanged).
            if wanderer.perchOnDrop() {
                isLifted = false
                return
            }
            // Otherwise the drop point becomes the new home spot (a learning signal in v2), then it falls to the floor.
            if let vf = screen?.visibleFrame {
                homeX = min(1, max(0, (panel.frame.minX - vf.minX) / max(1, vf.width - panel.frame.width)))
                defaults.set(homeX, forKey: "homeX")
            }
            dropToFloor()
        }
    }

    /// Falls from wherever it was dropped, accelerating, then squashes on landing.
    func dropToFloor() {
        renderer.react(.swing(0))
        let target = homeFrame()
        let height = max(0, panel.frame.minY - target.minY)
        let duration = min(0.55, max(0.12, sqrt(height / 2600)))
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isLifted = false
                self.renderer.react(.land(intensity: min(1, self.dragPeakSpeed / 2500)))
            }
        })
    }

    func showCard() {
        guard let a = active else { return }
        // A digest envelope opens the digest itself; the generic card would only add a step.
        if a.item.id.hasPrefix("digest:") {
            resolveActive(.opened)
            digest.show()
            return
        }
        envelope.actions = EnvelopeActions(
            open: { [weak self] in
                self?.envelope.close()
                if a.item.id.hasPrefix("ask:") || a.item.id.hasPrefix("browser:") {
                    self?.ask.reopen()
                } else if a.item.kind == .agent, let id = a.item.sourceApp,
                   let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                    app.activate()
                } else if let url = a.item.openURL { NSWorkspace.shared.open(url) }
                else if a.item.kind == .meeting { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app")) }
                else if a.item.kind == .mail { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mail.app")) }
                self?.resolveActive(.opened)
            },
            copy: a.item.id.hasPrefix("ask:") ? { [weak self] in self?.ask.card.copy(); self?.envelope.close() } : nil,
            notThisKind: { [weak self] in
                guard let self else { return }
                self.waiting.removeFirst()
                Task {
                    guard let rule = try? await self.engine.notThisKindAgain(a) else { return }
                    await MainActor.run { self.envelope.showReceipt(rule) }
                }
                self.justShooed = true
                self.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                    self?.justShooed = false
                    self?.refresh()
                }
            },
            later: { [weak self] in self?.envelope.close() },
            undo: { [weak self] in
                guard let self, let rule = self.envelope.model.savedRule else { return }
                Task { try? await self.engine.deleteRule(id: rule.id) }
                self.envelope.close()
                DiagnosticsLog.write("rules: undid \(rule.id)")
            },
            editRule: { [weak self] in
                self?.envelope.close()
                self?.showRules()
            })
        envelope.show(a, gist: gistByDecision[a.id] ?? a.item.subject, avoiding: cardAvoidRect())
    }

    // MARK: presence
}
