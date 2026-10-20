import AppKit
import HushCore
import HushMac
import SwiftUI

/// History (docs/design-guide.md §5.8): a standard window with a lane filter and search, rows grouped by day,
/// and a footer with the count and this month's spend. Space on a selected row reopens its answer, read-only.
@MainActor
final class HistoryModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", quick = "Quick", repo = "Repo", handoff = "Hand-off", browser = "Browser"
        var id: String { rawValue }
    }

    @Published var tasks: [AgentTask] = []
    @Published var filter: Filter = .all
    @Published var search = ""
    @Published var selection: String?

    /// Questions only (app router actions are logged too, but they aren't questions).
    var questions: [AgentTask] { tasks.filter { $0.repo != "action" } }

    var shown: [AgentTask] {
        questions.filter { t in
            let laneOK: Bool = switch filter {
            case .all: true
            case .quick: t.repo == "quick"
            case .repo: !["quick", "handoff", "browser", "sessions"].contains(t.repo)
            case .handoff: t.repo == "handoff"
            case .browser: t.repo == "browser"
            }
            return laneOK && (search.isEmpty || t.prompt.localizedCaseInsensitiveContains(search)
                              || t.result.localizedCaseInsensitiveContains(search))
        }
    }

    /// Newest day first.
    var days: [(day: Date, tasks: [AgentTask])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: shown) { cal.startOfDay(for: $0.startedAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.startedAt > $1.startedAt }) }
    }

    var monthCost: Double {
        let cal = Calendar.current
        return questions.filter { cal.isDate($0.startedAt, equalTo: Date(), toGranularity: .month) }.map(\.costUSD).reduce(0, +)
    }
}

struct HistoryActions {
    var reopen: (AgentTask) -> Void
    var forget: () -> Void
}

struct HistoryView: View {
    @ObservedObject var model: HistoryModel
    let actions: HistoryActions

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $model.selection) {
                ForEach(model.days, id: \.day) { group in
                    Section(Self.dayTitle(group.day)) {
                        ForEach(group.tasks, id: \.id) { t in HistoryRow(task: t).tag(t.id) }
                    }
                }
            }
            .listStyle(.inset)
            .overlay {
                if model.shown.isEmpty {
                    Text(model.questions.isEmpty ? "Nothing yet. Press ⌘⇧H to ask me something." : "No matches.")
                        .foregroundStyle(.secondary)
                }
            }
            .onKeyPress(.space) {
                guard let id = model.selection, let t = model.tasks.first(where: { $0.id == id }) else { return .ignored }
                actions.reopen(t)
                return .handled
            }
            Divider()
            HStack {
                Text("Kept on this Mac · \(model.questions.count) questions · \(Self.money(model.monthCost)) this month")
                    .font(HushFont.footer).foregroundStyle(.secondary)
                Spacer()
                Button("Forget history…", action: actions.forget)
                    .buttonStyle(.borderless).foregroundStyle(HushColor.failed)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .searchable(text: $model.search, placement: .toolbar, prompt: "Search questions")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Lane", selection: $model.filter) {
                    ForEach(HistoryModel.Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    static func dayTitle(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    static func money(_ v: Double) -> String { "$" + String(format: "%.2f", v) }
}

/// lane symbol · question · lane and app · model · cost · result.
struct HistoryRow: View {
    let task: AgentTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(tone.text).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.prompt).font(HushFont.body).lineLimit(1)
                Text(laneText).font(HushFont.footer).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(AskController.modelName(task.model)).font(HushFont.footer).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            Text(task.costUSD > 0 ? "$" + String(format: "%.3f", task.costUSD) : "–")
                .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
            result.frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var result: some View {
        if task.repo == "browser" {
            switch task.status {
            case .done: HushTag(text: "done", tone: .green)
            case .failed: HushTag(text: "didn't work", tone: .red)
            default: HushTag(text: "stopped", tone: .grey)
            }
        } else {
            Text(task.status == .done ? task.time : task.status.rawValue)
                .font(HushFont.footer).foregroundStyle(.tertiary)
        }
    }

    private var symbol: String {
        switch task.repo {
        case "quick": "bolt.fill"
        case "handoff": "arrow.up.right"
        case "browser": "safari"
        case "sessions": "terminal"
        default: "chevron.left.forwardslash.chevron.right"
        }
    }
    private var tone: Tone {
        switch task.repo {
        case "quick": .lilac
        case "handoff": .coral
        case "browser": .blue
        case "sessions": .green
        default: .grey
        }
    }
    private var laneText: String {
        switch task.repo {
        case "quick": "Quick answer"
        case "handoff": "Opened in \(task.model.capitalized)"
        case "browser": "Browser task"
        case "sessions": "Your sessions · on this Mac"
        default: "\(task.repoName) · read-only"
        }
    }
}

private extension AgentTask {
    var time: String { startedAt.formatted(date: .omitted, time: .shortened) }
}

@MainActor
final class HistoryWindowController {
    let model = HistoryModel()
    private var window: NSWindow?
    var engine: DecisionEngine?
    var actions: HistoryActions?

    func show() {
        Task {
            model.tasks = (try? await engine?.agentTasks(limit: 500)) ?? []
            let w = window ?? make()
            window = w
            NSApp.activate()
            w.makeKeyAndOrderFront(nil)
        }
    }

    func reload() { Task { model.tasks = (try? await engine?.agentTasks(limit: 500)) ?? [] } }

    private func make() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "History"
        w.isReleasedWhenClosed = false
        w.toolbarStyle = .unified
        w.toolbar = NSToolbar(identifier: "history")
        w.contentView = NSHostingView(rootView: HistoryView(model: model, actions: actions ?? .init(reopen: { _ in }, forget: {})))
        w.center()
        return w
    }
}
