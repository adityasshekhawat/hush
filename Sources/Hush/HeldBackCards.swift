import AppKit
import HushCore
import SwiftUI

/// The held-back count (docs/design-guide.md §5.2): the daily tuck-in card and Friday's weekly card.
/// The number is the proof of restraint; it never appears on the menu bar glyph.
@MainActor
final class HeldBackModel: ObservableObject {
    enum Kind { case day, week }
    @Published var kind: Kind = .day
    @Published var day = DaySummary(shown: 0, heldBack: 0)
    @Published var week = DaySummary(shown: 0, heldBack: 0)
    @Published var weekDays: [DaySummary] = []
    @Published var held: [HeldGroup] = []
    @Published var showList = false
    /// A VIP's mail is among what was held (then the card mustn't reassure).
    @Published var vipHeld = false
}

struct HeldBackActions {
    var goodnight: () -> Void
    var whatILearned: () -> Void
    var close: () -> Void
    var relayout: () -> Void
}

struct HeldBackView: View {
    @ObservedObject var model: HeldBackModel
    let actions: HeldBackActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                IconTile(symbol: "moon.fill", tone: .lilac)
                Text(model.kind == .day ? "Tonight" : "This week").font(HushFont.footer).foregroundStyle(.secondary)
                Spacer()
                Text(Date().formatted(date: .omitted, time: .shortened))
                    .font(HushFont.footer.monospacedDigit()).foregroundStyle(.tertiary)
            }
            if model.kind == .day { day } else { week }
        }
        .onChange(of: model.showList) { _, _ in actions.relayout() }
    }

    // MARK: daily

    @ViewBuilder private var day: some View {
        HStack(alignment: .firstTextBaseline, spacing: 22) {
            number(model.day.shown, "shown", color: .primary)
            number(model.day.heldBack, "held back", color: HushColor.lilacInk)
        }
        Text(summaryLine).font(HushFont.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        if model.showList { heldList }
        HStack(spacing: 8) {
            if model.day.heldBack > 0 {
                Button(model.showList ? "Hide the list" : "See what I held") { model.showList.toggle() }
                    .buttonStyle(HushPill(kind: .secondary))
            }
            Spacer()
            Button("Goodnight", action: actions.goodnight).buttonStyle(HushPill(kind: .primary)).keyboardShortcut(.defaultAction)
        }
    }

    private func number(_ n: Int, _ label: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(n)").font(HushFont.number(30)).foregroundStyle(color)
            Text(label).font(HushFont.subtitle).foregroundStyle(.secondary)
        }
    }

    /// One line on what was held. VIPs come up only to reassure.
    private var summaryLine: String {
        if model.day.shown == 0 && model.day.heldBack == 0 { return "Quiet day. Nothing needed you." }
        var parts: [String] = []
        for (i, g) in model.held.prefix(2).enumerated() {
            var label = g.label
            // "mail from a and b", not "mail from a and mail from b".
            if i == 1, label.hasPrefix("mail from "), model.held[0].label.hasPrefix("mail from ") { label = String(label.dropFirst(10)) }
            parts.append(label + (g.count > 1 ? " (\(g.count))" : ""))
        }
        let held = parts.isEmpty ? "" : "Mostly " + parts.joined(separator: " and ") + ". "
        return held + (model.vipHeld ? "" : "Nothing from your VIPs waited.")
    }

    private var heldList: some View {
        InnerBlock(padding: 10) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(model.held.prefix(8), id: \.category) { g in
                    HStack {
                        Text(g.label.prefix(1).uppercased() + g.label.dropFirst()).font(HushFont.subtitle).lineLimit(1)
                        Spacer()
                        Text("\(g.count)").font(HushFont.subtitle.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                if model.held.count > 8 {
                    Text("and \(model.held.count - 8) more kinds").font(HushFont.footer).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: weekly

    @ViewBuilder private var week: some View {
        Text("I kept \(model.week.heldBack) things off your screen.").font(HushFont.cardTitle).fixedSize(horizontal: false, vertical: true)
        WeekChart(days: model.weekDays)
        Text("You got \(model.week.shown) from me. The rest waited, quietly.").font(HushFont.subtitle).foregroundStyle(.secondary)
        HStack(spacing: 8) {
            Button("What I learned", action: actions.whatILearned).buttonStyle(HushPill(kind: .secondary))
            Spacer()
            Button("Close", action: actions.close).buttonStyle(HushPill(kind: .quiet)).keyboardShortcut(.cancelAction)
        }
    }
}

/// Five days: lilac bars for held back, with an ink inset for what was shown.
struct WeekChart: View {
    let days: [DaySummary]
    static let labels = ["M", "T", "W", "T", "F"]

    var body: some View {
        let top = max(1, days.map { $0.heldBack + $0.shown }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(Array(days.prefix(5).enumerated()), id: \.offset) { i, d in
                VStack(spacing: 5) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(HushColor.lilac)
                            .frame(height: max(4, 70 * CGFloat(d.heldBack + d.shown) / CGFloat(top)))
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(HushColor.primaryFill)
                            .frame(width: 10, height: d.shown == 0 ? 0 : max(3, 70 * CGFloat(d.shown) / CGFloat(top)))
                            .padding(.bottom, 2)
                    }
                    .frame(width: 26, height: 70, alignment: .bottom)
                    Text(i < Self.labels.count ? Self.labels[i] : "").font(HushFont.footer).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityLabel(days.prefix(5).enumerated().map { "\(Self.labels[$0.offset]): \($0.element.heldBack) held, \($0.element.shown) shown" }.joined(separator: ", "))
    }
}

/// Owns the held-back card.
@MainActor
final class HeldBackPresenter {
    let model = HeldBackModel()
    private var card: CardWindow?
    var engine: DecisionEngine?
    var onWhatILearned: (() -> Void)?
    var onGoodnight: (() -> Void)?
    var vips: () -> Set<String> = { [] }

    func show(_ kind: HeldBackModel.Kind, avoiding character: NSRect, list: Bool = false) {
        Task {
            guard let e = engine else { return }
            model.kind = kind
            model.showList = list
            model.day = (try? await e.daySummary()) ?? model.day
            model.week = (try? await e.weekSummary()) ?? model.week
            model.weekDays = (try? await e.weekDays()) ?? []
            model.held = (try? await e.heldToday()) ?? []
            let vips = self.vips()
            model.vipHeld = model.held.contains { g in
                guard g.category.hasPrefix("mail:") else { return false }
                let addr = String(g.category.dropFirst(5)).lowercased()
                return vips.contains(addr) || addr.split(separator: "@").last.map { vips.contains("@" + $0) } == true
            }
            let c = card ?? CardWindow(width: 320) { [unowned self] in
                HeldBackView(model: self.model, actions: .init(
                    goodnight: { [weak self] in self?.card?.close(); self?.onGoodnight?() },
                    whatILearned: { [weak self] in self?.card?.close(); self?.onWhatILearned?() },
                    close: { [weak self] in self?.card?.close() },
                    relayout: { [weak self] in DispatchQueue.main.async { self?.card?.resize() } }))
            }
            card = c
            c.show(avoiding: character)
            DispatchQueue.main.async { c.resize() }
        }
    }

    func relayout(avoiding character: NSRect) { card?.relayout(avoiding: character) }
    func close() { card?.close() }
}
