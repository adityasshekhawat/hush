import AppKit
import HushCore
import HushMac
import SwiftUI

/// "While you were away" (opt-in): when you come back after a while, Hush lists what your Claude Code sessions did,
/// built locally from their transcripts. "Summarise" is the only thing that sends anything off the Mac.
@MainActor
final class DigestController: ObservableObject {
    struct Host {
        var anchor: () -> NSRect
        /// Hand the "While you were away" envelope to the decision engine (gentle, capped, queued in calls).
        var submit: (InboxItem) -> Void
        /// Bundle id of the app a session runs in, if Hush has seen it through the hooks.
        var hostApp: (String) -> String?
        var react: (Reaction) -> Void
    }

    @Published var digests: [SessionDigest] = []
    @Published var window: DateInterval?
    @Published var summaries: [String: String] = [:]
    /// Also tell the Ask Hush card when a summary arrives or fails (session id, summary or nil).
    var onSummary: ((String, String?) -> Void)?
    @Published var summarising: Set<String> = []

    private let host: Host
    private let defaults = UserDefaults.standard
    private var awaySince: Date?
    private var card: CardWindow?

    init(host: Host) { self.host = host }

    var enabled: Bool {
        get { defaults.bool(forKey: "digestEnabled") }
        set { defaults.set(newValue, forKey: "digestEnabled") }
    }

    // MARK: opt-in

    /// Ask before reading anything. Returns whether it's now on.
    @discardableResult
    func toggleWithConsent() -> Bool {
        if enabled { enabled = false; DiagnosticsLog.write("digest: off"); return false }
        let a = NSAlert()
        a.messageText = "Show a digest of your Claude Code sessions when you come back?"
        a.informativeText = """
            When you return after 10 minutes or more, Hush reads your Claude Code session transcripts on this Mac \
            (~/.claude/projects) and lists, per session: what you asked, files changed, commands and commits, pull \
            requests, and Claude's last message.

            Nothing leaves your Mac. The optional Summarise button sends a short excerpt of one session to Claude.
            """
        a.addButton(withTitle: "Allow")
        a.addButton(withTitle: "Not now")
        NSApp.activate()
        a.window.level = .modalPanel
        guard a.runModal() == .alertFirstButtonReturn else { return false }
        enabled = true
        DiagnosticsLog.write("digest: on")
        return true
    }

    // MARK: away → back

    func focusChanged(away: Bool, now: Date = Date()) {
        if away {
            if awaySince == nil { awaySince = now }
            return
        }
        guard let since = awaySince else { return }
        awaySince = nil
        guard enabled, AwayRules.shouldOffer(awaySince: since, now: now) else { return }
        Task { await prepare(window: DateInterval(start: since, end: now), offer: true) }
    }

    /// Menu: "Show digest now" (last few hours).
    func showNow() {
        Task {
            let now = Date()
            await prepare(window: DateInterval(start: now.addingTimeInterval(-AwayRules.manualLookback), end: now), offer: false)
            show()
        }
    }

    private func prepare(window w: DateInterval, offer: Bool) async {
        let found = await TranscriptScanner.digests(in: w)
        window = w
        digests = found
        summaries = [:]
        DiagnosticsLog.write("digest: \(found.count) sessions in \(Int(w.duration / 60)) min")
        guard offer, !found.isEmpty else { return }
        let files = Set(found.flatMap { s in s.filesChanged.map { s.cwd + "/" + $0 } }).count
        host.submit(InboxItem(
            id: "digest:\(Int(w.end.timeIntervalSince1970))", kind: .agent, senderName: "Hush",
            subject: "While you were away",
            snippet: "\(found.count) Claude Code session\(found.count == 1 ? "" : "s")" + (files > 0 ? " · \(files) file\(files == 1 ? "" : "s") changed" : ""),
            receivedAt: w.end, project: found.first?.project))
    }

    // MARK: card

    func show() {
        let c = card ?? CardWindow(width: DigestView.width, maxHeight: 560) { [unowned self] in DigestView(controller: self) }
        card = c
        c.show(avoiding: host.anchor())
        DispatchQueue.main.async { c.resize() }
    }

    func close() { card?.close() }
    var isOpen: Bool { card?.isOpen ?? false }

    func relayout(avoiding character: NSRect) { card?.relayout(avoiding: character) }

    /// The card's content changed size (a summary arrived).
    func resize() { DispatchQueue.main.async { self.card?.resize() } }

    // MARK: actions

    func open(_ d: SessionDigest) {
        let id = host.hostApp(d.sessionID) ?? "com.apple.Terminal"
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first { app.activate() }
        else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// The only network step: a short, capped excerpt of one session to the summarise lane's model (Haiku by default) for a 2–3 sentence summary.
    func summarise(_ d: SessionDigest) {
        guard !summarising.contains(d.id) else { return }
        summarising.insert(d.id)
        var o = ClaudeCodeRunner.Options(cwd: FileManager.default.temporaryDirectory,
                                         prompt: "Summarise what this coding session accomplished:\n\n" + d.excerpt, allowedTools: [])
        o.apply(LaneSettings.spec(.summarise))
        o.systemPrompt = "Summarise a developer's Claude Code session in 2-3 plain sentences: what was done, what's left or needs review. No preamble."
        let r = ClaudeCodeRunner(options: o)
        let id = d.id
        DiagnosticsLog.write("digest: summarising \(d.project)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            r.run { event in
                guard case .finished(let result, _, _, _, _) = event else {
                    if case .failed = event {
                        DispatchQueue.main.async { MainActor.assumeIsolated { _ = self?.summarising.remove(id); self?.onSummary?(id, nil) } }
                    }
                    return
                }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.summaries[id] = result.trimmingCharacters(in: .whitespacesAndNewlines)
                        _ = self?.summarising.remove(id)
                        self?.onSummary?(id, self?.summaries[id])
                        self?.relayout(avoiding: self?.host.anchor() ?? .zero)
                    }
                }
            }
        }
    }
}

// MARK: - View

/// While you were away (docs/design-guide.md §5.7), 440 pt: header with the time away, a title with the count,
/// one block per session (at most 5), Summarise in place, and the privacy line.
struct DigestView: View {
    @ObservedObject var controller: DigestController
    static let width: CGFloat = 440
    static let maxSessions = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                IconTile(symbol: "moon.fill", tone: .lilac)
                Text("While you were away" + (controller.window.map { " · " + Self.span($0) } ?? ""))
                    .font(HushFont.footer).foregroundStyle(.secondary)
                Spacer()
                Button(action: controller.close) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 20, height: 20).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(HushFont.cardTitle)
                if !controller.digests.isEmpty { Text(subtitle).font(HushFont.subtitle).foregroundStyle(.secondary) }
            }
            if controller.digests.isEmpty {
                Text("No Claude Code activity in that time.").font(HushFont.body).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(controller.digests.prefix(Self.maxSessions)) { d in SessionRow(d: d, controller: controller) }
                        if controller.digests.count > Self.maxSessions {
                            Text("and \(controller.digests.count - Self.maxSessions) more in History")
                                .font(HushFont.footer).foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxHeight: 420)
            }
            Text("Read on this Mac from ~/.claude/projects. Summarise sends a short excerpt to Claude.")
                .font(HushFont.footer).foregroundStyle(.tertiary)
        }
        .onChange(of: controller.summaries) { _, _ in controller.resize() }
        .onChange(of: controller.summarising) { _, _ in controller.resize() }
    }

    private var title: String {
        let n = controller.digests.count
        return n == 0 ? "All quiet" : n == 1 ? "1 Claude session ran" : "\(n) Claude sessions ran"
    }

    private var subtitle: String {
        let d = controller.digests
        let counts: [(Int, String)] = [(d.filter { $0.status == .finished }.count, "finished"),
                                       (d.filter { $0.status == .working }.count, "working"),
                                       (d.filter { $0.status == .stopped }.count, "stopped")]
        return counts.filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: " · ")
    }

    static func span(_ w: DateInterval) -> String {
        let m = Int(w.duration / 60)
        return m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
    }
}

/// One session: project (bold), branch (mono), status tag; title; You asked / Claude; meta; Open · Summarise.
private struct SessionRow: View {
    let d: SessionDigest
    @ObservedObject var controller: DigestController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(d.project).font(HushFont.body.weight(.semibold))
                if let b = d.branch { Text(b).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
                StatusTag(status: d.status)
            }
            Text(d.title).font(HushFont.body).lineLimit(2)
            if let p = d.lastPrompt {
                (Text("You asked: ").italic().foregroundColor(.secondary) + Text(p))
                    .font(HushFont.subtitle).lineLimit(2)
            }
            if let s = controller.summaries[d.id] {
                Text(s).font(HushFont.subtitle).fixedSize(horizontal: false, vertical: true)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(light: .white, dark: NSColor.white.withAlphaComponent(0.08)),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if controller.summarising.contains(d.id) {
                SkeletonLines()
            } else if let m = d.lastMessage {
                (Text("Claude: ").italic().foregroundColor(.secondary) + Text(m))
                    .font(HushFont.subtitle).lineLimit(3)
            }
            HStack(spacing: 4) {
                Text(meta).font(HushFont.footer).foregroundStyle(.tertiary).lineLimit(1)
                if let pr = d.pullRequests.first, let u = URL(string: pr) {
                    Text("·").font(HushFont.footer).foregroundStyle(.tertiary)
                    Button("PR") { NSWorkspace.shared.open(u) }.buttonStyle(.plain)
                        .font(HushFont.footer.weight(.medium)).foregroundStyle(HushColor.working)
                }
            }
            HStack(spacing: 6) {
                small("Open") { controller.open(d) }
                if controller.summaries[d.id] == nil, !controller.summarising.contains(d.id) {
                    small("Summarise") { controller.summarise(d) }
                        .help("Sends a short excerpt of this session to Claude")
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .labelColor).opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var meta: String {
        var parts: [String] = []
        parts.append(d.filesChanged.isEmpty ? "no files" : d.filesChanged.count == 1 ? "1 file" : "\(d.filesChanged.count) files")
        if d.commits > 0 { parts.append(d.commits == 1 ? "1 commit" : "\(d.commits) commits") }
        let mins = max(1, Int(d.end.timeIntervalSince(d.start) / 60))
        parts.append(mins < 60 ? "\(mins) min" : "\(mins / 60) h \(mins % 60) min")
        return parts.joined(separator: " · ")
    }

    /// Small pills, 24 pt.
    private func small(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(HushPill(kind: .secondary, height: 24))
    }
}

private struct StatusTag: View {
    let status: SessionDigest.Status
    var body: some View {
        switch status {
        case .working: HushTag(text: "working", tone: .blue)
        case .finished: HushTag(text: "finished", tone: .green)
        case .stopped: HushTag(text: "stopped", tone: .red)
        }
    }
}
