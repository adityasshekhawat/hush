import AppKit
import HushCore
import HushMac
import SwiftUI

/// What I've learned (docs/design-guide.md §5.3), 420 pt: every rule as a first-person sentence you can edit in
/// place. The rule is stored as data; the sentence is generated from it and edits are parsed back in code.
/// Forget leaves a 6 s Undo in the row's place. "+ Add a rule" at the bottom.
@MainActor
final class RulesModel: ObservableObject {
    @Published var rules: [UserRule] = []
    /// Rule id → the text being edited.
    @Published var drafts: [String: String] = [:]
    /// Rule ids whose last edit didn't parse.
    @Published var unclear: Set<String> = []
    /// Forgotten just now (Undo shows in its row for 6 s).
    @Published var forgotten: [String: UserRule] = [:]
    @Published var adding = false
    @Published var newText = ""
    @Published var newUnclear = false
}

struct RulesActions {
    var save: (UserRule) -> Void
    var forget: (UserRule) -> Void
    var undoForget: (UserRule) -> Void
    var close: () -> Void
}

struct RulesView: View {
    @ObservedObject var model: RulesModel
    let actions: RulesActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                IconTile(symbol: "pencil.line", tone: .lilac)
                Text("What I've learned").font(HushFont.cardTitle)
                Spacer()
                Button("Close", action: actions.close).buttonStyle(HushPill(kind: .quiet)).keyboardShortcut(.cancelAction)
            }
            if model.rules.isEmpty && model.forgotten.isEmpty && !model.adding {
                Text(verbatim: "Nothing yet. When you tell me “not this kind again”, I'll write it down here.")
                    .font(HushFont.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.id) { rule in
                    if let gone = model.forgotten[rule.id] {
                        HStack {
                            Text("Forgotten.").font(HushFont.body).foregroundStyle(.secondary)
                            Spacer()
                            Button("Undo") { actions.undoForget(gone) }.buttonStyle(HushPill(kind: .secondary))
                        }
                        .frame(height: 32)
                    } else {
                        RuleRow(rule: rule, model: model, actions: actions)
                    }
                }
                if model.adding { addRow }
            }
            if !model.adding {
                Button { model.adding = true } label: { Label("Add a rule", systemImage: "plus") }
                    .buttonStyle(HushPill(kind: .quiet))
            }
            Text(verbatim: "Rules run on this Mac, in code. Try “Hold back mail from news@shop.com” or “Always show me mail from anyone at acme.com”.")
                .font(HushFont.footer).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rows: [UserRule] {
        (model.rules + model.forgotten.values.filter { f in !model.rules.contains { $0.id == f.id } })
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Hold back mail from…", text: $model.newText)
                .textFieldStyle(.plain).font(HushFont.body)
                .padding(.horizontal, 10).frame(height: 32)
                .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onSubmit {
                    let base = UserRule(match: .category("meeting"), action: .never)
                    if let rule = RuleText.parse(model.newText, base: base) {
                        actions.save(rule)
                        model.newText = ""; model.adding = false; model.newUnclear = false
                    } else { model.newUnclear = true }
                }
            if model.newUnclear {
                Text("I didn't follow that one.").font(HushFont.footer).foregroundStyle(Tone.orange.text)
            }
        }
    }
}

struct RuleRow: View {
    let rule: UserRule
    @ObservedObject var model: RulesModel
    let actions: RulesActions

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                TextField("", text: Binding(
                    get: { model.drafts[rule.id] ?? RuleText.sentence(rule) },
                    set: { model.drafts[rule.id] = $0 }))
                    .textFieldStyle(.plain).font(HushFont.body)
                    .onSubmit(commit)
                Button("Forget") { actions.forget(rule) }
                    .buttonStyle(.plain).font(HushFont.footer.weight(.medium)).foregroundStyle(HushColor.failed)
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            if model.unclear.contains(rule.id) {
                Text("I didn't follow that one, so I kept the old rule.").font(HushFont.footer).foregroundStyle(Tone.orange.text)
            }
        }
    }

    private func commit() {
        guard let text = model.drafts[rule.id] else { return }
        if let edited = RuleText.parse(text, base: rule) {
            model.unclear.remove(rule.id)
            model.drafts[rule.id] = nil
            if edited != rule { actions.save(edited) }
        } else {
            model.unclear.insert(rule.id)
            model.drafts[rule.id] = nil
        }
    }
}

/// Owns the rules card.
@MainActor
final class RulesPresenter {
    let model = RulesModel()
    private var card: CardWindow?
    var engine: DecisionEngine?

    func show(avoiding character: NSRect) {
        let c = card ?? CardWindow(width: 420, keyable: true) { [unowned self] in
            RulesView(model: self.model, actions: .init(
                save: { [weak self] r in self?.save(r) },
                forget: { [weak self] r in self?.forget(r) },
                undoForget: { [weak self] r in self?.undoForget(r) },
                close: { [weak self] in self?.card?.close() }))
        }
        card = c
        Task {
            model.rules = (try? await engine?.rules()) ?? []
            c.show(avoiding: character, makeKey: true)
            DispatchQueue.main.async { c.resize() }
        }
    }

    func relayout(avoiding character: NSRect) { card?.relayout(avoiding: character) }

    private func reload() {
        Task {
            model.rules = (try? await engine?.rules()) ?? []
            card?.resize()
        }
    }

    private func save(_ r: UserRule) {
        Task { try? await engine?.addRule(r); reload() }
        DiagnosticsLog.write("rules: saved \(r.id)")
    }

    private func forget(_ r: UserRule) {
        model.forgotten[r.id] = r
        Task { try? await engine?.deleteRule(id: r.id); reload() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.model.forgotten[r.id] = nil
            self?.card?.resize()
        }
        DiagnosticsLog.write("rules: forgot \(r.id)")
    }

    private func undoForget(_ r: UserRule) {
        model.forgotten[r.id] = nil
        save(r)
    }
}
