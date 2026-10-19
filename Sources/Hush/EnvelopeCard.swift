import AppKit
import HushCore
import SwiftUI

/// The card that opens when you click Hush while it's holding something (docs/design-guide.md §5.1), 320 pt.
/// Header (icon tile, source and when, clock time) · title · subtitle (why you're seeing it) · gist (3 lines) ·
/// Open · Not this kind again · Later. Return opens, Esc is Later. Read-only: Open hands off; nothing is sent.
/// After "Not this kind again" the same card becomes a receipt with Undo and Edit rule, and closes after 6 s.
final class EnvelopeModel: ObservableObject {
    @Published var decision: Decision?
    @Published var gist = ""
    /// Set after "Not this kind again": the rule just saved.
    @Published var savedRule: UserRule?
    /// "Also waiting: api (needs you), web (finished)": other agent sessions in line (ADR-024).
    @Published var also = ""
}

struct EnvelopeActions {
    var open: () -> Void
    var copy: (() -> Void)?
    var notThisKind: () -> Void
    var later: () -> Void
    /// Meetings about to start: "1 more min" (ADR-025).
    var snooze: (() -> Void)? = nil
    var undo: () -> Void
    var editRule: () -> Void
}

struct EnvelopeView: View {
    @ObservedObject var model: EnvelopeModel
    let actions: EnvelopeActions

    var body: some View {
        if let d = model.decision {
            let v = EnvelopeVariant(d)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    IconTile(symbol: model.savedRule == nil ? v.symbol : "pencil.line", tone: model.savedRule == nil ? v.tone : .lilac)
                    Text(v.source).font(HushFont.footer).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(d.item.receivedAt.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()))
                        .font(HushFont.footer.monospacedDigit()).foregroundStyle(.tertiary)
                }
                if let rule = model.savedRule {
                    Text("Got it. I'll hold these back.").font(HushFont.cardTitle)
                    Text("“\(RuleText.sentence(rule))”").font(HushFont.subtitle).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Undo", action: actions.undo).buttonStyle(HushPill(kind: .secondary))
                        Button("Edit rule", action: actions.editRule).buttonStyle(HushPill(kind: .quiet))
                        Spacer()
                    }
                    .padding(.top, 4)
                } else {
                    Text(v.title).font(HushFont.cardTitle).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if !v.subtitle.isEmpty {
                        Text(v.subtitle).font(HushFont.subtitle).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let detail = v.detail {
                        Text(detail).font(HushFont.body).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    }
                    if !model.gist.isEmpty, model.gist != v.title, model.gist != d.item.snippet {
                        Text(model.gist).font(HushFont.body).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    }
                    if !model.also.isEmpty {
                        Text(model.also).font(HushFont.footer).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Button(v.openTitle, action: actions.open).buttonStyle(HushPill(kind: .primary))
                            .keyboardShortcut(.defaultAction)
                        if let copy = actions.copy, v.offersCopy {
                            Button("Copy", action: copy).buttonStyle(HushPill(kind: .secondary))
                        }
                        if let snooze = actions.snooze {
                            Button("1 more min", action: snooze).buttonStyle(HushPill(kind: .secondary))
                        }
                        if v.offersNotThisKind {
                            Button("Not this kind again", action: actions.notThisKind).buttonStyle(HushPill(kind: .secondary))
                        }
                        Spacer(minLength: 0)
                        Button("Later", action: actions.later).buttonStyle(HushPill(kind: .quiet))
                            .keyboardShortcut(.cancelAction)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

/// What each kind of envelope looks like (the guide's variant table).
struct EnvelopeVariant {
    let symbol: String
    let tone: Tone
    let source: String
    let title: String
    let subtitle: String
    let openTitle: String
    let offersNotThisKind: Bool
    let offersCopy: Bool
    /// A body line under the subtitle: what an agent asks for (up to 3 lines).
    var detail: String?

    init(_ d: Decision) {
        let item = d.item
        let ago = Self.when(item.receivedAt)
        let app = item.sourceApp.flatMap(Self.appName)
        switch item.kind {
        case .meeting:
            let interrupt = d.finalLevel == .interrupt
            symbol = "calendar.badge.clock"; tone = .orange
            source = "Calendar · " + (item.startsAt.map(Self.until) ?? ago)
            title = interrupt ? "\(item.subject) is starting" : item.subject
            subtitle = Self.timeRange(item) + (item.snippet.isEmpty ? "" : " · \(item.snippet)")
            let call = item.openURL?.scheme == "https"
            openTitle = call ? "Join" : "Open in Calendar"
            offersNotThisKind = !interrupt
            offersCopy = false
        case .mail:
            symbol = "envelope.fill"; tone = .blue
            source = "Mail · \(ago)"
            title = item.subject
            let who = item.senderName ?? item.senderAddress ?? "Someone"
            subtitle = d.reasons.contains(where: { $0.contains("VIP") }) ? "\(who) is on your VIP list"
                : d.reasons.contains(where: { $0.hasPrefix("rule") }) ? "One of your rules: always show \(who)" : who
            openTitle = "Open in Mail"
            offersNotThisKind = true
            offersCopy = false
        case .agent:
            if item.id.hasPrefix("ask:") {
                symbol = "bolt.fill"; tone = .lilac
                source = "Ask Hush · \(ago)"
                title = "Answer ready"
                subtitle = "“\(item.snippet)”"
                openTitle = "Open"
                offersNotThisKind = false
                offersCopy = true
            } else if item.id.hasPrefix("browser:") {
                symbol = "safari"; tone = .blue
                source = "Browser task · \(ago)"
                title = "Browser task done"
                subtitle = item.snippet
                openTitle = "Open"
                offersNotThisKind = false
                offersCopy = false
            } else if item.id.contains(":approval:") {
                // What it asks for gets the body, so a long command isn't cut to one line (ADR-024).
                let risky = item.id.hasSuffix(":risky")
                symbol = risky ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill"
                tone = risky ? .red : .orange
                source = "\(item.senderName ?? "Agent") · \(ago)"
                title = item.subject
                subtitle = app.map { "In \($0)" } ?? ""
                detail = item.snippet
                openTitle = app.map { "Open \($0)" } ?? "Open"
                offersNotThisKind = !risky
                offersCopy = false
            } else if item.id.contains(":error:") {
                symbol = "xmark.octagon.fill"; tone = .grey
                source = "\(item.senderName ?? "Agent") · \(ago)"
                title = item.subject
                subtitle = [item.snippet, app].compactMap { $0 }.joined(separator: " · ")
                openTitle = app.map { "Open \($0)" } ?? "Open"
                offersNotThisKind = true
                offersCopy = false
            } else {
                symbol = "checkmark.circle.fill"; tone = .green
                source = "\(item.senderName ?? "Agent") · \(ago)"
                title = item.subject
                subtitle = [item.snippet, app].compactMap { $0 }.joined(separator: " · ")
                openTitle = "Open"
                offersNotThisKind = true
                offersCopy = false
            }
        }
    }

    static func appName(_ bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
    }

    static func when(_ date: Date) -> String {
        let m = Int(Date().timeIntervalSince(date) / 60)
        return m < 1 ? "just now" : m < 60 ? "\(m) min ago" : "\(m / 60) h ago"
    }

    static func until(_ date: Date) -> String {
        let m = Int(date.timeIntervalSinceNow / 60)
        return m <= 0 ? "now" : "in \(m) min"
    }

    /// "15:00 to 15:30" (24 h).
    static func timeRange(_ item: InboxItem) -> String {
        guard let start = item.startsAt else { return "" }
        let f = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        return start.formatted(f)
    }
}

/// Owns the envelope's card window.
@MainActor
final class EnvelopePresenter {
    let model = EnvelopeModel()
    private var card: CardWindow?
    var actions: EnvelopeActions?
    private var autoClose: DispatchWorkItem?

    var isOpen: Bool { card?.isOpen ?? false }

    func show(_ d: Decision, gist: String, also: String = "", avoiding character: NSRect) {
        model.decision = d
        model.gist = gist
        model.also = also
        model.savedRule = nil
        autoClose?.cancel()
        let c = card ?? CardWindow(width: 320, keyable: true) { [unowned self] in
            EnvelopeView(model: self.model, actions: self.actions ?? .init(open: {}, copy: nil, notThisKind: {}, later: {}, undo: {}, editRule: {}))
        }
        card = c
        // Opened by a click on Hush: take keys (Return opens, Esc is Later) without activating Hush.
        c.show(avoiding: character, makeKey: true)
        DispatchQueue.main.async { c.resize() }
    }

    /// Turn the card into the rule receipt; it closes itself after 6 s.
    func showReceipt(_ rule: UserRule) {
        model.savedRule = rule
        card?.resize()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        autoClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    func relayout(avoiding character: NSRect) { card?.relayout(avoiding: character) }

    func close() {
        autoClose?.cancel()
        card?.close()
    }
}
