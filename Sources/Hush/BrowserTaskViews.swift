import AppKit
import HushCore
import SwiftUI

// Browser tasks on the answer card (docs/design-guide.md §5.6): plan, running (step discs), a question box with a
// countdown, done. Copy follows the README: the card says what code enforces and what the model is told.

/// Before it runs: a one-line summary, up to 7 numbered steps, "asks first" tags, the sites note.
struct PlanBody: View {
    let plan: TaskPlan
    let browserName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plan.summary).font(HushFont.cardTitle).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(plan.steps.prefix(7).enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        NumberDisc(n: i + 1)
                        Text(step.text).font(HushFont.body).fixedSize(horizontal: false, vertical: true)
                        if step.irreversible { HushTag(text: "asks first", tone: .orange) }
                    }
                }
                if plan.steps.count > 7 {
                    Text("and \(plan.steps.count - 7) more").font(HushFont.footer).foregroundStyle(.tertiary).padding(.leading, 29)
                }
            }
            InnerBlock {
                VStack(alignment: .leading, spacing: 4) {
                    if !plan.domains.isEmpty {
                        (Text("Opens only ") + Text(plan.domains.joined(separator: ", ")).bold()
                            + Text(". A new address asks you first; links it clicks aren't checked."))
                            .font(HushFont.footer).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("It's told to ask before sending, buying or deleting, and never to type passwords.")
                        .font(HushFont.footer).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Running: the last 5 plan steps (green ✓ done, blue current, grey waiting), a working line, and a question
/// when it needs one.
struct BrowserProgress: View {
    @ObservedObject var model: AnswerModel
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let plan = model.plan {
                let current = model.currentStep ?? 1
                let start = max(0, min(current - 2, plan.steps.count - 5))
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(plan.steps.enumerated()).dropFirst(start).prefix(5), id: \.offset) { i, step in
                        let n = i + 1
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            NumberDisc(n: n, tone: n < current ? .done : n == current ? .current : .waiting)
                            Text(step.text).font(HushFont.body).lineLimit(2)
                                .foregroundStyle(n > current ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        }
                        .opacity(n > current ? 0.45 : 1)
                    }
                }
            }
            if !model.activity.isEmpty, model.prompt == nil {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(model.activity).font(HushFont.subtitle).foregroundStyle(HushColor.working).lineLimit(1)
                }
            }
            if let p = model.prompt { QuestionBox(prompt: p, answer: answer) }
        }
    }
}

/// "Before I do this" / "This needs your OK": the question, its consequence, No · Yes, go ahead, and an mm:ss
/// countdown. Unanswered counts as no.
struct QuestionBox: View {
    let prompt: GatePrompt
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(prompt.kind == .confirm ? "Before I do this" : "This needs your OK",
                  systemImage: "exclamationmark.circle.fill")
                .font(HushFont.tag).foregroundStyle(Tone.orange.text)
            Text(prompt.text).font(HushFont.answerBody).fixedSize(horizontal: false, vertical: true)
            Text(prompt.kind == .confirm ? "This can't be undone from here." : "It wasn't in the plan you approved.")
                .font(HushFont.footer).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("No") { answer(false) }.buttonStyle(HushPill(kind: .secondary))
                Button("Yes, go ahead") { answer(true) }.buttonStyle(HushPill(kind: .consent))
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let left = max(0, Int(prompt.deadline.timeIntervalSince(ctx.date)))
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            Text("Unanswered counts as no.").font(HushFont.footer).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(light: NSColor(hex: 0xFFF4E3), dark: NSColor.systemOrange.withAlphaComponent(0.14)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color(light: NSColor(hex: 0xFFD79A), dark: NSColor.systemOrange.withAlphaComponent(0.4)), lineWidth: 1))
    }
}

/// Done: the result, a note, and the steps on request.
struct BrowserDone: View {
    @ObservedObject var model: AnswerModel
    @State private var showSteps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let lines = model.text.split(separator: "\n", maxSplits: 1).map(String.init)
            Text(lines.first ?? "Done.").font(HushFont.cardTitle).fixedSize(horizontal: false, vertical: true)
            if lines.count > 1 {
                Text(lines[1]).font(HushFont.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                if let url = model.resultURL {
                    Button("Open the page") { NSWorkspace.shared.open(url) }.buttonStyle(HushPill(kind: .primary))
                }
                if model.plan != nil {
                    Button(showSteps ? "Hide steps" : "See steps") { showSteps.toggle() }.buttonStyle(HushPill(kind: .secondary))
                }
            }
            if showSteps, let plan = model.plan {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(plan.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            NumberDisc(n: i + 1, tone: .done)
                            Text(step.text).font(HushFont.body).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
