import AppKit
import HushCore
import HushMac
import SwiftUI

/// What the answer card shows (docs/ask-design.md § Answer shapes). Updated live while a run streams.
@MainActor
final class AnswerModel: ObservableObject {
    enum Phase: Equatable {
        case working
        /// Browser task: the plan is on the card, waiting for Approve.
        case awaitingApproval
        case done
        case handedOff(AskLane.Provider)
        case failed(String)
        case cancelled
    }

    @Published var question = ""
    @Published var lane: AskLane = .quick
    /// "in Excel": the app you were in, when it shaped the answer.
    @Published var context: String?
    @Published var phase: Phase = .working
    @Published var activity = ""
    /// Quick lane: the structured answer.
    @Published var shape: AnswerShape?
    /// Repo lane (and quick-lane fallback): streamed text.
    @Published var text = ""
    @Published var footer = ""
    @Published var copied = false
    /// App router: up to three actions for this answer, primary first, and what the last one did.
    @Published var actions: [AppAction] = []
    @Published var receipt: String? { didSet { receiptAt = receipt == nil ? nil : Date() } }
    /// When the receipt appeared (it fades after 8 s).
    @Published var receiptAt: Date?
    /// Repo lane: tools used so far, in first-use order ("Read ×6").
    @Published var toolCounts: [ToolCount] = []
    @Published var turns = 0

    /// Browser task: the plan, what's happened so far, and a question waiting for you.
    @Published var plan: TaskPlan?
    @Published var steps: [String] = []
    @Published var prompt: GatePrompt?
    /// The browser the task runs in ("Comet").
    @Published var browserName: String?
    /// The plan step it's on (1-based, reported by the model), how many times you said yes, and the page it ended on.
    @Published var currentStep: Int?
    @Published var okCount = 0
    @Published var resultURL: URL?
    @Published var runStartedAt: Date?
    /// The sessions lane: one line per session, summaries as they arrive.
    @Published var sessions: [SessionLine] = []
    @Published var sessionsFromTranscripts = false
    /// A live sessions report is on the card (a reopened one from History is just its text).
    @Published var isSessionsReport = false
    @Published var sessionSummaries: [String: String] = [:]
    @Published var summarising: Set<String> = []
    /// The session opened on the card (its live view), its recent turns, what Hush is watching, and the composer.
    @Published var selectedSession: String?
    @Published var sessionTurns: [SessionTurn] = []
    @Published var watched: Set<String> = []
    @Published var sendToClaude = false
    @Published var composeText = ""
    @Published var sessionReceipt: String? { didSet { sessionReceiptAt = Date() } }
    @Published var sessionReceiptAt = Date()

    var selectedLine: SessionLine? { sessions.first { $0.id == selectedSession } }

    func countTool(_ name: String) {
        if let i = toolCounts.firstIndex(where: { $0.name == name }) { toolCounts[i].count += 1 }
        else { toolCounts.append(ToolCount(name: name, count: 1)) }
    }

    var copyText: String { shape?.plainText ?? text }
}

/// A browser task needs a yes from you: a site outside the plan (code asked), or a step it says is irreversible.
struct GatePrompt: Equatable, Identifiable {
    let id = UUID()
    var kind: GateRequest.Kind
    var text: String
    /// Unanswered by then counts as no.
    var deadline = Date().addingTimeInterval(290)
}

struct ToolCount: Equatable {
    var name: String
    var count: Int
}

/// The card under the command box. Non-activating: it never takes focus from the app you're in.
/// Sizes itself to its content (up to a cap, then scrolls). Chrome, motion and placement: CardWindow.
@MainActor
final class AnswerCard {
    let model = AnswerModel()
    private var card: CardWindow?
    private var anchor: NSRect = .zero
    var onStop: (() -> Void)?
    var onClose: (() -> Void)?
    var onContinue: ((AskLane.Provider) -> Void)?
    var onAction: ((AppAction) -> Void)?
    var onApprove: (() -> Void)?
    var onPrompt: ((Bool) -> Void)?
    var onFollowUp: (() -> Void)?
    var onRetry: (() -> Void)?
    var onOpenSession: ((SessionLine) -> Void)?
    var onSummariseSession: ((SessionLine) -> Void)?
    var onSelectSession: ((String?) -> Void)?
    var onToggleWatch: ((SessionLine) -> Void)?
    var onCompose: ((SessionLine) -> Void)?
    /// Show "Follow up" on finished answers (false at the turn cap).
    var canFollowUp: () -> Bool = { false }
    /// Which assistant "Continue in…" offers.
    var continueProvider: AskLane.Provider = .chatgpt

    static let width: CGFloat = 420
    static let maxHeight: CGFloat = 480

    var isOpen: Bool { card?.isOpen ?? false }
    /// Where the card is on screen (the command box opens above it for a follow-up).
    var frame: NSRect? { card?.frame }
    var window: NSWindow? { card?.window }

    func show(above anchor: NSRect) {
        self.anchor = anchor
        let c = card ?? makeCard()
        card = c
        c.show(avoiding: anchor)
    }

    /// Re-fit the card to its content, keeping it just above Hush.
    func resize() { card?.resize() }

    /// Hush moved or changed pose: keep clear of it.
    func relayout(avoiding character: NSRect) {
        guard isOpen else { return }
        anchor = character
        card?.relayout(avoiding: character)
    }

    func close() {
        card?.close()
        onClose?()
    }

    private func makeCard() -> CardWindow {
        let view = AnswerView(model: model, actions: .init(
            stop: { [weak self] in self?.onStop?() },
            close: { [weak self] in self?.close() },
            copy: { [weak self] in self?.copy() },
            continueIn: { [weak self] in
                guard let self else { return }
                self.onContinue?(self.continueProvider)
            },
            continueName: { [weak self] in self?.continueProvider.displayName ?? "ChatGPT" },
            perform: { [weak self] a in self?.onAction?(a) },
            approve: { [weak self] in self?.onApprove?() },
            answerPrompt: { [weak self] ok in self?.onPrompt?(ok) },
            followUp: { [weak self] in self?.onFollowUp?() },
            retry: { [weak self] in self?.onRetry?() },
            openSession: { [weak self] l in self?.onOpenSession?(l) },
            summariseSession: { [weak self] l in self?.onSummariseSession?(l) },
            selectSession: { [weak self] id in self?.onSelectSession?(id) },
            toggleWatch: { [weak self] l in self?.onToggleWatch?(l) },
            compose: { [weak self] l in self?.onCompose?(l) },
            canFollowUp: { [weak self] in self?.canFollowUp() ?? false },
            relayout: { [weak self] in DispatchQueue.main.async { self?.resize() } }))
        // Keyable: the session composer is a text field (the card still never takes focus until you click it).
        return CardWindow(width: Self.width, maxHeight: 620, keyable: true) { view }
    }

    func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.copyText, forType: .string)
        PlaySensors.ownCopyChangeCount = NSPasteboard.general.changeCount
        model.copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.model.copied = false }
    }
}
