import AppKit
import HushCore
import HushMac

/// The local, readable log of everything you asked (Principle 4: scrutable). Agent → Show / Forget history.
extension AskController {
    func showHistory() {
        history.engine = host.engine
        history.actions = HistoryActions(
            reopen: { [weak self] t in self?.showReadOnly(t) },
            forget: { [weak self] in self?.confirmForget() })
        history.show()
    }

    /// Space on a history row: the answer card, read-only.
    func showReadOnly(_ t: AgentTask) {
        let m = card.model
        m.question = t.prompt
        m.lane = t.repo == "quick" ? .quick : t.repo == "browser" ? .browser : t.repo == "sessions" ? .sessions
            : t.repo == "handoff" ? .handoff(AskLane.Provider(rawValue: t.model) ?? .chatgpt) : .repo(path: t.repo)
        m.shape = nil
        m.plan = nil
        m.isSessionsReport = false
        m.text = t.result
        m.actions = []
        m.receipt = nil
        m.context = t.startedAt.formatted(.dateTime.day().month().hour().minute())
        m.footer = ""
        m.phase = t.status == .done ? .done : t.status == .failed ? .failed(t.result) : .cancelled
        card.show(above: host.anchor())
    }

    private func confirmForget() {
        let a = NSAlert()
        a.messageText = "Forget your Ask Hush history?"
        a.informativeText = "Every question and answer kept on this Mac is deleted. This can't be undone."
        a.addButton(withTitle: "Forget").hasDestructiveAction = true
        a.addButton(withTitle: "Cancel")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        forgetHistory()
        history.reload()
    }

    func forgetHistory() {
        Task { try? await host.engine.deleteAgentTasks() }
        let url = URL(fileURLWithPath: HushStore.defaultPath()).deletingLastPathComponent().appendingPathComponent("agent-history.md")
        try? FileManager.default.removeItem(at: url)
        DiagnosticsLog.write("ask: history forgotten")
    }
}
