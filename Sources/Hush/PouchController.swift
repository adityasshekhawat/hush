import AppKit
import HushCore
import HushMac
import SwiftUI

/// "Hand it to Hush" (ADR-019): with full cheeks, a click on Hush offers verbs for what you copied; Hush chews and
/// hands the reworked text back on the clipboard, ready for ⌘V (which blows the cheeks out, as any paste does).
/// The clipboard's text is read only here, when you click, and only on this Mac.
@MainActor
final class PouchController {
    struct Host {
        var anchor: () -> NSRect
        var react: (Reaction) -> Void
        var bubble: (String) -> Void
        /// Pop the cheeks (the old click behaviour; "Never mind").
        var emptyCheeks: () -> Void
        var handoff: () -> AskLane.Provider
    }

    private let host: Host
    private let rewriter = OnDeviceRewriter()
    private let defaults = UserDefaults.standard
    private let model = PouchCardModel()
    private lazy var card = CardWindow(width: 360) { PouchCard(model: self.model) }
    private var clickAway: Any?
    /// What you copied before the last rework, and that rework, so "Original" can put it back.
    private var original: String?
    private var lastResult: String?
    private(set) var chewing = false

    init(host: Host) {
        self.host = host
        model.pick = { [weak self] verb in self?.rework(verb) }
        model.restore = { [weak self] in self?.restoreOriginal() }
        model.accept = { [weak self] in self?.consent(true) }
        model.decline = { [weak self] in self?.consent(false) }
        model.dismiss = { [weak self] in self?.close(); self?.host.emptyCheeks() }
    }

    /// Settings ▸ Ask Hush. On by default; the first click still asks before reading anything.
    var enabled: Bool {
        get { defaults.object(forKey: "pouchOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "pouchOn"); if !newValue { close() } }
    }
    private var consented: Bool { defaults.bool(forKey: "pouchConsent") }

    var isOpen: Bool { card.isOpen }

    /// A click on full-cheeked Hush. Returns false when the old behaviour (pop the cheeks) should run instead.
    func clicked() -> Bool {
        guard enabled, !chewing else { return chewing }
        if card.isOpen { close(); return true }
        if !consented {
            model.stage = .consent
            open()
            return true
        }
        guard let text = source() else {
            // macOS can refuse clipboard reads that aren't a paste (pasteboard privacy). Say so instead of failing quietly.
            if Self.accessDenied {
                model.stage = .blocked
                open()
                return true
            }
            return false
        }
        if case .tooLong(let n) = Pouch.check(text) {
            model.stage = .tooLong(n)
        } else if Pouch.check(text) == .code {
            model.stage = .code
        } else {
            model.stage = .verbs(canRestore: original != nil && NSPasteboard.general.string(forType: .string) == lastResult)
        }
        open()
        Task { await rewriter.prewarm() }
        return true
    }

    func relayout() { card.relayout(avoiding: host.anchor()) }

    /// The system's pasteboard privacy setting for Hush (macOS 15.4+).
    private static var accessDenied: Bool {
        if #available(macOS 15.4, *) { return NSPasteboard.general.accessBehavior == .alwaysDeny }
        return false
    }

    /// What each click could read, for diagnosing (lengths only, never the text).
    private func logRead(_ clip: String?) {
        var access = "n/a"
        if #available(macOS 15.4, *) {
            switch NSPasteboard.general.accessBehavior {
            case .default: access = "default"
            case .ask: access = "ask"
            case .alwaysAllow: access = "allow"
            case .alwaysDeny: access = "deny"
            @unknown default: access = "unknown"
            }
        }
        DiagnosticsLog.write("pouch: click · clipboard access \(access) · text \(clip.map { "\($0.count) chars" } ?? "none")")
    }

    /// Debug hook: open the chips, then pick a verb (the same path as a click on Hush, then on a chip).
    func debugPick(_ verb: PouchVerb) {
        guard clicked(), model.stage != .consent else { return }
        rework(verb)
    }

    /// The cheeks emptied (you pasted): the next copy starts fresh.
    func cheeksEmptied() {
        close()
        original = nil
        lastResult = nil
    }

    // MARK: steps

    /// The text to rework: what's on the clipboard, or the original if the clipboard still holds our last rework.
    private func source() -> String? {
        let clip = NSPasteboard.general.string(forType: .string)
        logRead(clip)
        if let lastResult, clip == lastResult, let original { return original }
        guard case .ok = Pouch.check(clip) else { return Pouch.check(clip) == .empty ? nil : clip }
        original = nil
        lastResult = nil
        return clip
    }

    private func open() {
        card.show(avoiding: host.anchor())
        host.react(.boxPose("sitListen"))
        clickAway = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func close() {
        if let m = clickAway { NSEvent.removeMonitor(m); clickAway = nil }
        if card.isOpen { card.close() }
        if !chewing { host.react(.boxPose(nil)) }
    }

    private func consent(_ yes: Bool) {
        defaults.set(yes, forKey: "pouchConsent")
        if yes {
            close()
            _ = clicked()
        } else {
            enabled = false
            close()
            host.emptyCheeks()
            host.bubble("Okay. Turn it on any time in Settings ▸ Ask Hush.")
        }
    }

    private func rework(_ verb: PouchVerb) {
        switch model.stage {
        case .tooLong, .unavailable: handOff(verb); return
        case .consent, .verbs, .code, .blocked: break
        }
        guard let text = source(), case .ok(let clean) = Pouch.check(text) else { close(); return }
        close()
        chewing = true
        host.react(.boxPose(nil))
        host.react(.chew(true))
        let copiedAt = NSPasteboard.general.changeCount
        Task {
            do {
                let out = try await rewriter.rework(clean, verb: verb)
                finish {
                    // You copied something else while Hush chewed: that's what you want now, so leave it be.
                    guard NSPasteboard.general.changeCount == copiedAt else {
                        self.host.bubble("You copied something new, so I let that one go.")
                        return
                    }
                    self.original = self.original ?? text
                    self.lastResult = out
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(out, forType: .string)
                    PlaySensors.ownCopyChangeCount = pb.changeCount   // our copy: no gulp
                    self.host.react(.handOver)
                    self.host.bubble("\(verb.done). Press ⌘V.")
                }
            } catch OnDeviceRewriter.Failure.unavailable {
                finish {
                    self.host.react(.sorry)
                    self.model.stage = .unavailable(verb)
                    self.open()
                }
            } catch {
                finish {
                    self.host.react(.sorry)
                    self.host.bubble("I couldn't chew that one. Your clipboard is just as you left it.")
                }
            }
        }
    }

    private func finish(_ then: @escaping @MainActor () -> Void) {
        chewing = false
        host.react(.chew(false))
        then()
    }

    private func restoreOriginal() {
        close()
        guard let original else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(original, forType: .string)
        PlaySensors.ownCopyChangeCount = pb.changeCount
        lastResult = nil
        self.original = nil
        host.react(.handOver)
        host.bubble("Back to what you copied. Press ⌘V.")
    }

    /// The model can't help (Apple Intelligence off, or too much text): your assistant can. The text is already
    /// on the clipboard, so only the instruction goes in the link.
    private func handOff(_ verb: PouchVerb) {
        close()
        let p = host.handoff()
        let claudeApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "claude://x")!) != nil
        guard let url = p.url(for: Pouch.handoffQuestion("(I'll paste the text next.)", verb: verb), appInstalled: claudeApp) else { return }
        NSWorkspace.shared.open(url)
        host.react(.wave)
        host.bubble("Opened \(p.displayName). Press ⌘V there to paste your text.")
    }
}

// MARK: - The card

@MainActor
final class PouchCardModel: ObservableObject {
    enum Stage: Equatable {
        case consent
        case verbs(canRestore: Bool)
        case tooLong(Int)
        case code
        case unavailable(PouchVerb)
        /// macOS didn't let Hush read the clipboard.
        case blocked
    }
    @Published var stage: Stage = .verbs(canRestore: false)
    var pick: (PouchVerb) -> Void = { _ in }
    var restore: () -> Void = {}
    var accept: () -> Void = {}
    var decline: () -> Void = {}
    var dismiss: () -> Void = {}
}

private struct PouchCard: View {
    @ObservedObject var model: PouchCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.stage {
            case .consent:
                Text("Want me to rework what you copy?").font(HushFont.cardTitle)
                Text("When you click me with full cheeks, I read the text you copied and can make it simpler, shorter or into bullets. It stays on this Mac.")
                    .font(HushFont.body).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Not now", action: model.decline).buttonStyle(.pill(.secondary))
                    Button("Sounds good", action: model.accept).buttonStyle(.pill(.primary))
                }
            case .verbs(let canRestore):
                Text("What should I do with it?").font(HushFont.subtitle).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(PouchVerb.allCases, id: \.self) { v in
                        Button { model.pick(v) } label: { Label(v.title, systemImage: v.symbol) }
                            .buttonStyle(.pill(.secondary))
                    }
                }
                HStack {
                    if canRestore {
                        Button { model.restore() } label: { Label("Original", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(.pill(.quiet))
                    }
                    Spacer()
                    Button("Never mind", action: model.dismiss).buttonStyle(.pill(.quiet))
                }
            case .tooLong(let n):
                Text("That's a big mouthful").font(HushFont.cardTitle)
                Text("\(n.formatted()) characters is more than I can chew on this Mac. Your assistant can take it.")
                    .font(HushFont.body).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(PouchVerb.allCases, id: \.self) { v in
                        Button(v.title) { model.pick(v) }.buttonStyle(.pill(.secondary))
                    }
                }
            case .code:
                Text("That looks like code").font(HushFont.cardTitle)
                Text("Simpler, shorter or bullets would break it, so I'll leave it as it is. Try me with some writing.")
                    .font(HushFont.body).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Got it", action: model.dismiss).buttonStyle(.pill(.secondary))
                }
            case .blocked:
                Text("macOS didn't let me see what you copied").font(HushFont.cardTitle)
                Text("You can allow Hush to read the clipboard in System Settings ▸ Privacy & Security. I only look when you click me.")
                    .font(HushFont.body).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Got it", action: model.dismiss).buttonStyle(.pill(.secondary))
                }
            case .unavailable(let verb):
                Text("I need Apple Intelligence for this").font(HushFont.cardTitle)
                Text("Turn it on in System Settings ▸ Apple Intelligence & Siri, and I can chew right here on your Mac. Or your assistant can do it now.")
                    .font(HushFont.body).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Never mind", action: model.dismiss).buttonStyle(.pill(.quiet))
                    Spacer()
                    Button("Ask your assistant") { model.pick(verb) }.buttonStyle(.pill(.primary))
                }
            }
        }
    }
}
