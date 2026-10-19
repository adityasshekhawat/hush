import HushCore
import SwiftUI

/// The command box's state. The route is recomputed on every keystroke so the chip always shows Hush's plan.
@MainActor
final class CommandBoxModel: ObservableObject {
    @Published var text = "" { didSet { recompute() } }
    @Published private(set) var route: AskRoute?
    /// Set by Tab or the chip menu; wins over the automatic route until the box closes.
    @Published var override: AskLane? { didSet { recompute() } }
    @Published var context = AskContext()
    /// Following up on the answer that's showing: same lane, earlier turns sent as context.
    @Published var followUp: FollowUp? { didSet { recompute() } }
    /// The 260 pt route menu above the field.
    @Published var menuOpen = false
    /// Your earlier corrections (the smarter router's learned layer).
    var learned = LearnedRoutes()

    /// Your pick wins, then an explicit @prefix, then the follow-up's lane, then the router.
    var lane: AskLane {
        if let o = override { return o }
        if let r = route, r.explicit { return r.lane }
        // A question about your sessions wins over the follow-up's lane: it needs live data, not the last answer.
        if let r = route, r.lane == .sessions { return .sessions }
        return followUp?.lane ?? route?.lane ?? .quick
    }

    func recompute() {
        var r = AskRouter.route(text, context: context)
        // A phrasing you've sent somewhere else before goes there again (unless you typed an @prefix).
        if !r.explicit, let kind = learned.lookup(r.text), let lane = kind.lane(for: r.text, context: context), lane != r.lane {
            r = AskRoute(lane: lane, text: r.text, why: "you sent one like this there before", explicit: false, confident: true)
        }
        route = r
    }

    /// Nobody's sure yet: no prefix, no lane picked, no follow-up, and only the rules' fallback matched.
    var needsCheck: Bool { override == nil && followUp == nil && route?.confident == false }

    /// You changed the lane from the router's pick: remember it for next time.
    var correction: LaneKind? {
        guard let o = override, let r = route, !r.explicit, LaneKind(o) != LaneKind(r.lane) else { return nil }
        return LaneKind(o)
    }

    func tab() { override = AskRouter.next(after: lane, context: context) }

    func reset() {
        override = nil
        followUp = nil
        menuOpen = false
        text = ""
    }

    /// The question as it'll be sent (prefix removed).
    var question: String { route?.text ?? text }
}

struct CommandBoxActions {
    var submit: () -> Void
    var cancel: () -> Void
    var addRepo: () -> Void
    /// At three follow-ups: carry the thread on in your assistant.
    var carryOn: () -> Void
}

/// The command box (docs/design-guide.md §5.4): a 420 × 46 field with the route chip trailing, a hint line under
/// it, and the route menu above it when open.
struct CommandBoxView: View {
    @ObservedObject var model: CommandBoxModel
    let actions: CommandBoxActions
    @FocusState private var focused: Bool

    static let width: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.menuOpen { RouteMenu(model: model, addRepo: actions.addRepo) }
            field
            Text(hint)
                .font(HushFont.footer).foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.leading, 14)
        }
        .frame(width: Self.width, alignment: .leading)
        .padding(CommandPanel.shadowMargin)
        .onAppear { focused = true }
        .animation(HushMotion.resize, value: model.menuOpen)
    }

    @ViewBuilder private var field: some View {
        HStack(spacing: 8) {
            if let f = model.followUp, f.isFull {
                Button(action: actions.carryOn) {
                    Text("That's three. Carry on in \(model.context.preferredHandoff.displayName) ↗")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                Button("", action: actions.cancel).keyboardShortcut(.cancelAction).opacity(0).frame(width: 0)
            } else {
                if let f = model.followUp { FollowUpChip(followUp: f) { model.followUp = nil } }
                TextField(placeholder, text: $model.text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($focused)
                    .onSubmit(actions.submit)
                    .onKeyPress(.tab) { model.tab(); return .handled }
                    // Backspace on an empty box drops the follow-up: ask something new.
                    .onKeyPress(.delete) {
                        guard model.text.isEmpty, model.followUp != nil else { return .ignored }
                        model.followUp = nil
                        return .handled
                    }
                    .onExitCommand { model.menuOpen ? (model.menuOpen = false) : actions.cancel() }
                RouteChip(model: model)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HushColor.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 12)
    }

    private var placeholder: String { model.followUp != nil ? "Ask a follow-up…" : "Ask Hush…" }

    private var hint: String {
        if let f = model.followUp, f.isFull { return "Return carry on · Esc close" }
        if let f = model.followUp, model.text.isEmpty { return "On “\(f.lastQuestion.prefix(40))” · Delete ask something new · Esc close" }
        return "Return ask · Tab change route · Esc close"
    }
}

/// "↩ Follow-up ×": ink chip on the leading side.
struct FollowUpChip: View {
    let followUp: FollowUp
    let clear: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.turn.down.left").font(.system(size: 9, weight: .bold))
            Text("Follow-up").font(HushFont.tag)
            Button(action: clear) { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                .buttonStyle(.plain)
                .help("Ask something new instead")
        }
        .foregroundStyle(HushColor.primaryText)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(HushColor.primaryFill, in: Capsule())
        .help("Builds on “\(followUp.lastQuestion)”")
    }
}

/// Route chips (§5.4): ⚡ answer here (lilac), ‹/› ask about repo (grey), ↗ open in Claude (coral),
/// 🧭 plan it for your browser (blue). Click for the route menu; Tab cycles.
struct RouteChip: View {
    @ObservedObject var model: CommandBoxModel

    var body: some View {
        Button { model.menuOpen.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: Self.symbol(model.lane)).font(.system(size: 9.5, weight: .bold))
                Text(Self.text(model.lane)).font(HushFont.tag).lineLimit(1)
            }
            .foregroundStyle(Self.tone(model.lane).text)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Self.tone(model.lane).fill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(model.route?.why ?? "")
    }

    static func text(_ lane: AskLane) -> String {
        switch lane {
        case .quick: "answer here"
        case .repo(let p): "ask about \(URL(fileURLWithPath: p).lastPathComponent)"
        case .handoff(let p): "open in \(p.displayName)"
        case .browser: "plan it for your browser"
        case .sessions: "check your sessions"
        }
    }
    static func symbol(_ lane: AskLane) -> String {
        switch lane {
        case .quick: "bolt.fill"
        case .repo: "chevron.left.forwardslash.chevron.right"
        case .handoff: "arrow.up.right"
        case .browser: "safari"
        case .sessions: "terminal"
        }
    }
    static func tone(_ lane: AskLane) -> Tone {
        switch lane {
        case .quick: .lilac
        case .repo: .grey
        case .handoff: .coral
        case .browser: .blue
        case .sessions: .green
        }
    }
}

/// The 260 pt route menu: the four routes, the selected one ink-filled, the model or a disclosure arrow trailing.
struct RouteMenu: View {
    @ObservedObject var model: CommandBoxModel
    let addRepo: () -> Void
    @State private var expanded: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row("Answer here", symbol: "bolt.fill", trailing: nil, selected: model.lane == .quick) { pick(.quick) }
            if model.context.repos.count <= 1 {
                if let r = model.context.repos.first {
                    row("Ask about \(name(r))", symbol: "chevron.left.forwardslash.chevron.right", trailing: "read-only", selected: model.lane == .repo(path: r)) { pick(.repo(path: r)) }
                } else {
                    row("Allow a repo…", symbol: "chevron.left.forwardslash.chevron.right", trailing: nil, selected: false, action: addRepo)
                }
            } else {
                row("Ask a repo", symbol: "chevron.left.forwardslash.chevron.right", trailing: expanded == "repo" ? "⌄" : "›",
                    selected: { if case .repo = model.lane { return true } else { return false } }()) { toggle("repo") }
                if expanded == "repo" {
                    ForEach(model.context.repos, id: \.self) { r in
                        row(name(r), symbol: nil, trailing: "read-only", selected: model.lane == .repo(path: r), indent: true) { pick(.repo(path: r)) }
                    }
                }
            }
            row("Open in…", symbol: "arrow.up.right", trailing: expanded == "handoff" ? "⌄" : "›",
                selected: { if case .handoff = model.lane { return true } else { return false } }()) { toggle("handoff") }
            if expanded == "handoff" {
                ForEach(AskLane.Provider.allCases, id: \.self) { p in
                    row(p.displayName, symbol: nil, trailing: nil, selected: model.lane == .handoff(p), indent: true) { pick(.handoff(p)) }
                }
            }
            row("Check your sessions", symbol: "terminal", trailing: "on this Mac", selected: model.lane == .sessions) { pick(.sessions) }
            if model.context.browserTasks {
                row("Plan it for your browser", symbol: "safari", trailing: "beta", selected: model.lane == .browser) { pick(.browser) }
            }
        }
        .padding(6)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HushColor.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 12)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func name(_ path: String) -> String { URL(fileURLWithPath: path).lastPathComponent }
    private func pick(_ lane: AskLane) { model.override = lane; model.menuOpen = false }
    private func toggle(_ key: String) { expanded = expanded == key ? nil : key }

    private func row(_ title: String, symbol: String?, trailing: String?, selected: Bool, indent: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 16) }
                Text(title).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 4)
                if let trailing { Text(trailing).font(HushFont.footer).opacity(0.6) }
            }
            .padding(.leading, indent ? 30 : 8)
            .padding(.trailing, 8)
            .frame(height: 28)
            .foregroundStyle(selected ? HushColor.primaryText : .primary)
            .background(selected ? HushColor.primaryFill : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
