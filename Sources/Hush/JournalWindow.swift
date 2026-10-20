import AppKit
import HushCore
import HushMac
import SwiftUI

/// "What Hush saw" (ADR-026): every item Hush looked at in the last 7 days, what it did and why, in plain words.
/// Proof, not a promise: it lives on this Mac, expires after 7 days, and Forget empties it.
@MainActor
final class JournalModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", shown = "Shown", held = "Held back"
        var id: String { rawValue }
    }

    @Published var entries: [LoggedDecision] = []
    @Published var filter: Filter = .all

    var shown: [LoggedDecision] {
        entries.filter { e in
            switch filter {
            case .all: true
            case .shown: e.outcome == .shown
            case .held: e.outcome != .shown
            }
        }
    }

    var days: [(day: Date, entries: [LoggedDecision])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: shown) { cal.startOfDay(for: $0.at) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!) }
    }
}

struct JournalView: View {
    @ObservedObject var model: JournalModel
    let forget: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $model.filter) {
                ForEach(JournalModel.Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 280).padding(12)
            Divider()
            if model.shown.isEmpty {
                VStack(spacing: 6) {
                    JournalCover().padding(.bottom, 10)
                    Text("Nothing here yet").font(HushFont.cardTitle)
                    Text("Everything I look at shows up here, with what I did and why.")
                        .font(HushFont.subtitle).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.days, id: \.day) { group in
                        Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                            ForEach(group.entries, id: \.id) { e in JournalRow(e: e) }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
                Text("Stays on this Mac · kept for \(Journal.keepDays) days · \(model.entries.count) \(model.entries.count == 1 ? "item" : "items")")
                    .font(HushFont.footer).foregroundStyle(.secondary)
                Spacer()
                Button("Forget…", action: forget).disabled(model.entries.isEmpty)
            }
            .padding(10)
        }
    }
}

/// The notebook's cover (v1 art), with the words the app draws on its plate: half size, 180 × 240 pt.
private struct JournalCover: View {
    static let art = NSImage(contentsOf: Assets.root.appendingPathComponent("ui/journal/cover.svg"))

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let art = Self.art { Image(nsImage: art).resizable().frame(width: 180, height: 240) }
            Text("What Hush saw").font(.system(size: 15, weight: .semibold)).foregroundStyle(HushColor.ink)
                .frame(width: 90, height: 32).offset(x: 45, y: 74)
            Text("Stays on this Mac").font(.system(size: 8)).foregroundStyle(HushColor.ink.opacity(0.7))
                .frame(width: 106, height: 10).offset(x: 37, y: 122)
        }
        .frame(width: 180, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

private struct JournalRow: View {
    let e: LoggedDecision

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, tone: tone, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(e.title?.isEmpty == false ? e.title! : Journal.source(e)).font(HushFont.body.weight(.medium)).lineLimit(1)
                    Spacer()
                    Text(e.at.formatted(date: .omitted, time: .shortened))
                        .font(HushFont.footer.monospacedDigit()).foregroundStyle(.tertiary)
                }
                Text(Journal.source(e)).font(HushFont.footer).foregroundStyle(.secondary).lineLimit(1)
                let why = Journal.why(e)
                Text(why.isEmpty ? Journal.outcome(e) : "\(Journal.outcome(e)) · \(why)")
                    .font(HushFont.footer).foregroundStyle(e.outcome == .shown ? .primary : .secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var symbol: String {
        switch e.kind {
        case .mail: "envelope.fill"
        case .meeting: "calendar"
        case .agent: "terminal"
        case nil: "circle"
        }
    }

    private var tone: Tone { e.outcome == .shown ? (e.finalLevel == .interrupt ? .orange : .lilac) : .grey }
}

@MainActor
final class JournalWindowController {
    let model = JournalModel()
    private var window: NSWindow?
    var engine: DecisionEngine?

    func show() {
        Task {
            await reload()
            let w = window ?? make()
            window = w
            NSApp.activate()
            w.makeKeyAndOrderFront(nil)
        }
    }

    func reload() async { model.entries = (try? await engine?.journal()) ?? [] }

    private func confirmForget() {
        let a = NSAlert()
        a.messageText = "Forget what Hush saw?"
        a.informativeText = "The journal on this Mac is emptied, and today's and this week's counts start again. Your rules stay. This can't be undone."
        a.addButton(withTitle: "Forget").hasDestructiveAction = true
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        Task {
            try? await engine?.forgetJournal()
            DiagnosticsLog.write("journal: forgotten")
            await reload()
        }
    }

    private func make() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "What Hush saw"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: JournalView(model: model, forget: { [weak self] in self?.confirmForget() }))
        w.center()
        return w
    }
}
