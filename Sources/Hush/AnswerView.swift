import AppKit
import HushCore
import SwiftUI

// Answer card, 420 pt (docs/design-guide.md §5.5): header (lane chip, status dot and word, Stop while running) ·
// the question · body shaped to the answer · action row (max 3) · receipt · footer (model · time · cost, Follow up).

struct AnswerActions {
    var stop: () -> Void
    var close: () -> Void
    var copy: () -> Void
    var continueIn: () -> Void
    var continueName: () -> String
    var perform: (AppAction) -> Void
    var approve: () -> Void
    var answerPrompt: (Bool) -> Void
    var followUp: () -> Void
    var retry: () -> Void
    var openSession: (SessionLine) -> Void
    var summariseSession: (SessionLine) -> Void
    var selectSession: (String?) -> Void
    var toggleWatch: (SessionLine) -> Void
    var compose: (SessionLine) -> Void
    var canFollowUp: () -> Bool
    var relayout: () -> Void
}

struct AnswerView: View {
    @ObservedObject var model: AnswerModel
    let actions: AnswerActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !model.question.isEmpty, !isHandoff {
                Text(model.question)
                    .font(HushFont.body).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            content
            footer
        }
        .animation(HushMotion.resize, value: model.phase)
        .onChange(of: model.phase) { _, _ in actions.relayout() }
        .onChange(of: model.shape) { _, _ in actions.relayout() }
        .onChange(of: model.text) { _, _ in actions.relayout() }
        .onChange(of: model.steps) { _, _ in actions.relayout() }
        .onChange(of: model.prompt) { _, _ in actions.relayout() }
        .onChange(of: model.receipt) { _, _ in actions.relayout() }
        .onChange(of: model.currentStep) { _, _ in actions.relayout() }
        .onChange(of: model.selectedSession) { _, _ in actions.relayout() }
        .onChange(of: model.sessionTurns.count) { _, _ in actions.relayout() }
        .onChange(of: model.sessionReceipt) { _, _ in actions.relayout() }
    }

    private var isHandoff: Bool { if case .handoff = model.lane { return true } else { return false } }
    private var isBrowser: Bool { model.lane == .browser }
    private var running: Bool { model.phase == .working }

    // MARK: header

    private var header: some View {
        HStack(spacing: 8) {
            LaneBadge(lane: model.lane)
            if isBrowser { HushTag(text: "BETA", tone: .grey) }
            StatusDot(text: status.word, color: status.color)
            if let c = model.context, !running { Text(c).font(HushFont.footer).foregroundStyle(.tertiary).lineLimit(1) }
            Spacer(minLength: 4)
            if running {
                Button(action: actions.stop) { Label("Stop", systemImage: "stop.fill").labelStyle(.titleAndIcon) }
                    .buttonStyle(HushPill(kind: .smallStop))
                    .keyboardShortcut(".", modifiers: .command)
            } else {
                Button(action: actions.close) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 20, height: 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
        }
    }

    private var status: (word: String, color: Color) {
        switch model.phase {
        case .working where model.prompt != nil: ("Needs you", HushColor.needsYou)
        case .working: (isBrowser && model.plan != nil ? "Working" : model.lane == .sessions ? "Looking" : "Thinking", HushColor.working)
        case .awaitingApproval: ("Plan ready", HushColor.needsYou)
        case .done: ("Done", HushColor.done)
        case .handedOff: ("Handed off", HushColor.done)
        case .failed: ("Didn't work", HushColor.failed)
        case .cancelled: ("Stopped", Color(nsColor: .tertiaryLabelColor))
        }
    }

    // MARK: body

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .handedOff(let p):
            HandoffBody(provider: p)
        case .failed(let why):
            FailedBlock(cause: why)
        case .awaitingApproval:
            if let plan = model.plan { PlanBody(plan: plan, browserName: model.browserName) }
        case .working where isBrowser && model.plan != nil:
            BrowserProgress(model: model, answer: actions.answerPrompt)
        case .done where isBrowser && model.plan != nil:
            BrowserDone(model: model)
        case .done where model.lane == .sessions && model.isSessionsReport:
            if let line = model.selectedLine {
                SessionDetail(model: model, line: line, actions: actions)
            } else {
                SessionsBody(model: model, open: actions.openSession, summarise: actions.summariseSession, select: actions.selectSession)
            }
        default:
            if let s = model.shape {
                ShapeBody(shape: s, copy: actions.copy, copied: model.copied)
            } else if !model.text.isEmpty || !model.toolCounts.isEmpty {
                RepoBody(model: model)
            } else if running {
                SkeletonLines()
            } else if model.phase == .cancelled {
                Text("Stopped.").font(HushFont.body).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: footer

    @ViewBuilder private var footer: some View {
        switch model.phase {
        case .working where isBrowser && model.plan != nil:
            FooterLine(left: browserProgressLine) { EmptyView() }
        case .working:
            if !model.activity.isEmpty, model.shape != nil || !model.text.isEmpty {
                FooterLine(left: model.activity) { EmptyView() }
            }
        case .awaitingApproval:
            HStack(spacing: 8) {
                Label("Runs in \(model.browserName ?? "your browser")", systemImage: "safari")
                    .font(HushFont.footer).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: actions.close).buttonStyle(HushPill(kind: .quiet))
                    .keyboardShortcut(.cancelAction)
                Button("Run it", action: actions.approve).buttonStyle(HushPill(kind: .primary, shortcut: "⌘⏎"))
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        case .done:
            VStack(alignment: .leading, spacing: 10) {
                if !model.actions.isEmpty {
                    ActionRow(actions: model.actions, copied: model.copied, perform: actions.perform)
                }
                if let r = model.receipt, let at = model.receiptAt { ReceiptLine(text: r, at: at) }
                FooterLine(left: footerText) {
                    if actions.canFollowUp() {
                        Button { actions.followUp() } label: { Label("Follow up", systemImage: "arrow.turn.down.left") }
                            .buttonStyle(HushPill(kind: .quiet))
                            .help("Ask a follow-up (⌘⇧H)")
                    }
                }
            }
        case .failed:
            HStack(spacing: 8) {
                Button("Try again", action: actions.retry).buttonStyle(HushPill(kind: .primary))
                if !isBrowser {
                    Button("Ask \(actions.continueName())", action: actions.continueIn).buttonStyle(HushPill(kind: .secondary))
                }
                Spacer()
                if isBrowser, model.okCount == 0 {
                    Text("Nothing was sent or changed.").font(HushFont.footer).foregroundStyle(.tertiary)
                }
            }
        case .cancelled:
            if isBrowser, model.okCount == 0 {
                FooterLine(left: "Nothing was sent or changed.") { EmptyView() }
            }
        default:
            EmptyView()
        }
    }

    private var footerText: String {
        guard isBrowser, let plan = model.plan else { return model.footer }
        let oks = model.okCount == 0 ? "" : model.okCount == 1 ? ", 1 OK from you" : ", \(model.okCount) OKs from you"
        return [model.footer, "\(plan.steps.count) steps\(oks)"].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var browserProgressLine: String {
        let elapsed = model.runStartedAt.map { AskController.seconds(Int(Date().timeIntervalSince($0) * 1000)) + " so far" }
        let step = model.currentStep.flatMap { n in model.plan.map { "step \(min(n, $0.steps.count)) of \($0.steps.count)" } }
        return [elapsed, step].compactMap { $0 }.joined(separator: " · ")
    }

    static func styled(_ text: String) -> AttributedString {
        // Block-level Markdown isn't rendered by Text: turn list markers and headings into plain typography first.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var l = String(line)
            if let r = l.range(of: #"^\s*[-*] "#, options: .regularExpression) { l.replaceSubrange(r, with: "•  ") }
            if let r = l.range(of: #"^#{1,4} "#, options: .regularExpression) { l = "**" + l[r.upperBound...] + "**" }
            return l
        }
        let joined = lines.joined(separator: "\n")
        return (try? AttributedString(markdown: joined, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(joined)
    }
}

// MARK: - Pieces

/// The lane chip, 20 pt tall: quick lilac, repo grey, hand-off coral, browser blue.
struct LaneBadge: View {
    let lane: AskLane
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9.5, weight: .bold))
            Text(label).font(HushFont.tag).lineLimit(1)
        }
        .foregroundStyle(tone.text)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(tone.fill, in: Capsule())
    }

    var label: String {
        switch lane {
        case .quick: "Quick answer"
        case .repo(let p): "\(URL(fileURLWithPath: p).lastPathComponent) · read-only"
        case .handoff(let p): p.displayName
        case .browser: "Browser task"
        case .sessions: "Your sessions"
        }
    }
    var icon: String {
        switch lane {
        case .quick: "bolt.fill"
        case .repo: "chevron.left.forwardslash.chevron.right"
        case .handoff: "arrow.up.right"
        case .browser: "safari"
        case .sessions: "terminal"
        }
    }
    var tone: Tone {
        switch lane {
        case .quick: .lilac
        case .repo: .grey
        case .handoff: .coral
        case .browser: .blue
        case .sessions: .green
        }
    }
}

/// Your sessions: a headline, then one block per session (project, branch, status, what you asked, what it said,
/// files), with Open and Summarise. Read on the Mac.
struct SessionsBody: View {
    @ObservedObject var model: AnswerModel
    let open: (SessionLine) -> Void
    let summarise: (SessionLine) -> Void
    let select: (String?) -> Void

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 8) {
            Text(SessionsReport.headline(model.sessions)).font(HushFont.cardTitle)
            if model.sessions.isEmpty {
                Text(HookInstaller.isInstalled
                     ? "When Claude Code or Codex runs, I'll know whether it's working, waiting for you or done."
                     : "I'm not watching Claude Code yet. Connect it in the menu bar panel and I'll know what every session is doing.")
                    .font(HushFont.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(model.sessions.prefix(SessionsReport.maxLines)) { line in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(line.project).font(HushFont.body.weight(.semibold))
                        if let b = line.branch { Text(b).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1) }
                        if line.agent == .codex { HushTag(text: "Codex", tone: .grey) }
                        if model.watched.contains(line.id) { HushTag(text: "watching", tone: .lilac, symbol: "eye") }
                        Spacer()
                        HushTag(text: SessionsReport.statusText(line, now: now), tone: tone(line.status))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    if let t = line.title { Text(t).font(HushFont.body).lineLimit(1) }
                    if let p = line.lastPrompt {
                        (Text("You asked: ").italic().foregroundColor(.secondary) + Text(p)).font(HushFont.subtitle).lineLimit(2)
                    }
                    if let s = model.sessionSummaries[line.id] {
                        Text(s).font(HushFont.subtitle).fixedSize(horizontal: false, vertical: true)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(light: .white, dark: NSColor.white.withAlphaComponent(0.08)),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if model.summarising.contains(line.id) {
                        SkeletonLines()
                    } else if let m = line.lastMessage {
                        (Text("\(line.agent.shortName): ").italic().foregroundColor(.secondary) + Text(m)).font(HushFont.subtitle).lineLimit(3)
                    }
                    if !line.files.isEmpty || line.commits > 0 {
                        Text(meta(line)).font(HushFont.footer).foregroundStyle(.secondary).lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        if line.app != nil { Button("Open") { open(line) }.buttonStyle(HushPill(kind: .secondary, height: 24)) }
                        if line.digest != nil, model.sessionSummaries[line.id] == nil, !model.summarising.contains(line.id) {
                            Button("Summarise") { summarise(line) }.buttonStyle(HushPill(kind: .secondary, height: 24))
                                .help("Sends a short excerpt of this session to Claude")
                        }
                    }
                }
                .padding(12)
                .modifier(SessionBlock())
                .contentShape(Rectangle())
                .onTapGesture { select(line.id) }
                .help("See what's happening and send it a message")
            }
            if let r = model.sessionReceipt { ReceiptLine(text: r, at: model.sessionReceiptAt) }
            if model.sessions.count > SessionsReport.maxLines {
                Text("and \(model.sessions.count - SessionsReport.maxLines) more").font(HushFont.footer).foregroundStyle(.tertiary)
            }
            if !model.sessionsFromTranscripts, !model.sessions.isEmpty {
                Text("Turn on the While you were away digest and I can say what each session did, too.")
                    .font(HushFont.footer).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: model.sessionSummaries) { _, _ in }
    }

    private func tone(_ s: SessionLine.Status) -> Tone {
        switch s {
        case .waiting: .orange
        case .working: .blue
        case .finished: .green
        case .stopped: .red
        case .idle: .grey
        }
    }

    private func meta(_ l: SessionLine) -> String {
        var parts: [String] = []
        if !l.files.isEmpty { parts.append(l.files.count == 1 ? "1 file: \(l.files[0])" : "\(l.files.count) files: \(l.files.prefix(3).joined(separator: ", "))") }
        if l.commits > 0 { parts.append(l.commits == 1 ? "1 commit" : "\(l.commits) commits") }
        return parts.joined(separator: " · ")
    }
}

/// One session, live: status, what's happening (the recent conversation, refreshed while open), a watch toggle,
/// Open, and a composer with two modes: Tell Hush (watch commands, questions about this session) or Send to Claude
/// (typed into its terminal tab).
struct SessionDetail: View {
    @ObservedObject var model: AnswerModel
    let line: SessionLine
    let actions: AnswerActions

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button { actions.selectSession(nil) } label: { Label("All sessions", systemImage: "chevron.left") }
                    .buttonStyle(HushPill(kind: .quiet))
                Spacer()
                HushTag(text: SessionsReport.statusText(line, now: now), tone: tone)
            }
            HStack(spacing: 6) {
                Text(line.project).font(HushFont.cardTitle)
                if let b = line.branch { Text(b).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary) }
                if line.agent == .codex { HushTag(text: "Codex", tone: .grey) }
            }
            if let t = line.title { Text(t).font(HushFont.subtitle).foregroundStyle(.secondary).lineLimit(1) }

            if model.sessionTurns.isEmpty {
                Text(model.sessionsFromTranscripts
                     ? "Nothing in its transcript yet."
                     : "Turn on the While you were away digest and I can show what this session is doing, live.")
                    .font(HushFont.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.sessionTurns) { turn in TurnRow(turn: turn, agent: line.agent).id(turn.id) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 230)
                    .onAppear { proxy.scrollTo(model.sessionTurns.last?.id, anchor: .bottom) }
                    .onChange(of: model.sessionTurns) { _, t in withAnimation(HushMotion.resize) { proxy.scrollTo(t.last?.id, anchor: .bottom) } }
                }
                .padding(10)
                .background(Color(nsColor: .labelColor).opacity(0.05), in: RoundedRectangle(cornerRadius: HushSpace.innerRadius, style: .continuous))
            }

            HStack(spacing: 6) {
                let watching = model.watched.contains(line.id)
                Button { actions.toggleWatch(line) } label: {
                    Label(watching ? "Watching for the finish" : "Let me know when it finishes", systemImage: watching ? "eye.fill" : "eye")
                }
                .buttonStyle(WatchPill(on: watching))
                if line.app != nil { Button("Open") { actions.openSession(line) }.buttonStyle(HushPill(kind: .secondary, height: 26)) }
                Spacer()
            }

            composer
            if let r = model.sessionReceipt { ReceiptLine(text: r, at: model.sessionReceiptAt) }
        }
    }

    @ViewBuilder private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            ModeSwitch(options: ["Tell Hush", "Send to \(line.agent.shortName)"], selected: model.sendToClaude ? 1 : 0) {
                model.sendToClaude = $0 == 1
            }
            let blocked = model.sendToClaude && line.status == .waiting
            HStack(spacing: 6) {
                TextField(model.sendToClaude ? "Message for \(line.agent.shortName)…" : "e.g. tell me when it finishes, or why is it slow?",
                          text: $model.composeText)
                    .textFieldStyle(.plain)
                    .font(HushFont.body)
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: HushSpace.innerRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HushSpace.innerRadius, style: .continuous).strokeBorder(HushColor.hairline, lineWidth: 0.5))
                    .onSubmit { if !blocked { actions.compose(line) } }
                    .disabled(blocked)
                Button(model.sendToClaude ? "Send" : "Tell") { actions.compose(line) }
                    .buttonStyle(HushPill(kind: .primary))
                    .disabled(blocked || model.composeText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text(hint(blocked: blocked)).font(HushFont.footer).foregroundStyle(blocked ? AnyShapeStyle(Tone.orange.text) : AnyShapeStyle(.secondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hint(blocked: Bool) -> String {
        if blocked { return "It's waiting on a permission prompt. Answer it in its window (Open), so nothing gets approved by accident." }
        guard model.sendToClaude else { return "Hush handles this: watching, or a question about this session." }
        return TerminalScript.canType(into: line.app) && line.tty != nil
            ? "Typed into its \(line.app == TerminalScript.iterm ? "iTerm" : "Terminal") tab, then Return. macOS asks once to let Hush do that."
            : "Copied, and its window comes forward so you can paste it."
    }

    private var tone: Tone {
        switch line.status {
        case .waiting: .orange
        case .working: .blue
        case .finished: .green
        case .stopped: .red
        case .idle: .grey
        }
    }
}

/// A session block in the list: the guide's inner block, a little brighter on hover so it reads as clickable.
struct SessionBlock: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .labelColor).opacity(hovering ? 0.07 : 0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HushColor.hairline, lineWidth: hovering ? 0.5 : 0))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Two-option switch in the guide's pill language (system segmented controls look dimmed in non-focusing panels).
struct ModeSwitch: View {
    let options: [String]
    let selected: Int
    let pick: (Int) -> Void
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, title in
                Button { pick(i) } label: {
                    Text(title).font(.system(size: 12, weight: i == selected ? .semibold : .medium))
                        .padding(.horizontal, 12).frame(height: 24)
                        .foregroundStyle(i == selected ? HushColor.primaryText : .primary)
                        .background(Capsule().fill(i == selected ? HushColor.primaryFill : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(HushColor.quietFill))
    }
}

/// The watch toggle: a secondary pill, lilac while watching (lilac is Hush's own colour; the primary pill stays Send).
struct WatchPill: ButtonStyle {
    let on: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: on ? .semibold : .medium))
            .padding(.horizontal, 12).frame(height: 26)
            .foregroundStyle(on ? Tone.lilac.text : .primary)
            .background(Capsule().fill(on ? Tone.lilac.fill : HushColor.quietFill))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct TurnRow: View {
    let turn: SessionTurn
    let agent: AgentKind
    var body: some View {
        switch turn.role {
        case .you:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HushTag(text: "You", tone: .grey)
                Text(turn.text).font(HushFont.subtitle).lineLimit(4).fixedSize(horizontal: false, vertical: true)
            }
        case .agent:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HushTag(text: agent.shortName, tone: .lilac)
                Text(turn.text).font(HushFont.subtitle).lineLimit(6).fixedSize(horizontal: false, vertical: true)
            }
        case .tool:
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver").font(.system(size: 10)).frame(width: 16)
                Text(turn.text).font(.system(size: 11.5, design: .monospaced)).lineLimit(1).truncationMode(.middle)
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
        }
    }
}

/// Thinking: two skeleton lines.
struct SkeletonLines: View {
    @State private var dim = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4).frame(height: 10)
            RoundedRectangle(cornerRadius: 4).frame(width: 240, height: 10)
        }
        .foregroundStyle(HushColor.quietFill.opacity(dim ? 1.4 : 2.2))
        .onAppear {
            guard !HushMotion.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
        }
    }
}

struct FooterLine<Trailing: View>: View {
    let left: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 6) {
            Text(left).font(HushFont.footer).foregroundStyle(.tertiary).lineLimit(1)
            Spacer(minLength: 4)
            trailing
        }
    }
}

/// "✓ Copied. Press ⌘V in Excel." on a green tint; fades after 8 s (stays with Reduce Motion).
struct ReceiptLine: View {
    let text: String
    let at: Date
    @State private var gone = false
    var body: some View {
        if !gone {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                Text(text).font(HushFont.footer).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Tone.green.text)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color(light: NSColor(hex: 0xE9F6EE), dark: NSColor.systemGreen.withAlphaComponent(0.18)),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .transition(.opacity)
            .task(id: at) {
                gone = false
                guard !HushMotion.reduceMotion else { return }
                try? await Task.sleep(for: .seconds(8))
                withAnimation(.easeOut(duration: 0.3)) { gone = true }
            }
        }
    }
}

/// Failed: a red-tint block with the plain cause and the fix.
struct FailedBlock: View {
    let cause: String
    var body: some View {
        InnerBlock(fill: Color(light: NSColor(hex: 0xFDF0EE), dark: NSColor.systemRed.withAlphaComponent(0.16)), padding: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(HushColor.failed)
                Text(cause).font(HushFont.body).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct HandoffBody: View {
    let provider: AskLane.Provider
    var body: some View {
        Text("Opened in \(provider.displayName) with your question filled in.")
            .font(HushFont.answerBody)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Repo answer: tool chips ("Read ×6"), then the streamed text with a caret while it runs.
struct RepoBody: View {
    @ObservedObject var model: AnswerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.toolCounts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(model.toolCounts.prefix(5), id: \.name) { t in
                        HushTag(text: t.count > 1 ? "\(t.name) ×\(t.count)" : t.name, tone: .grey)
                    }
                }
            }
            if !model.text.isEmpty || model.phase == .working {
                ScrollView {
                    (Text(AnswerView.styled(model.text)) + Text(model.phase == .working ? " ▍" : "").foregroundColor(.secondary))
                        .font(HushFont.answerBody).lineSpacing(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
        }
    }
}

/// The app router's buttons (docs/app-router-plan.md): the first is the primary pill, each with its app's real icon.
struct ActionRow: View {
    let actions: [AppAction]
    let copied: Bool
    let perform: (AppAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { i, a in
                Button { perform(a) } label: {
                    HStack(spacing: 6) {
                        ActionIcon(action: a)
                        Text(a.id == "copy" && copied ? "Copied" : a.title)
                    }
                }
                .buttonStyle(HushPill(kind: i == 0 ? .primary : .secondary))
                .keyboardShortcut(i == 0 ? KeyboardShortcut(.return, modifiers: [.command]) : nil)
                .help(a.receipt)
            }
            Spacer(minLength: 0)
        }
    }
}

struct ActionIcon: View {
    let action: AppAction
    var body: some View {
        if let id = action.target?.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                .frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: action.symbol).font(.system(size: 11, weight: .semibold)).frame(width: 16, height: 16)
        }
    }
}
