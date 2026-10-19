import AppKit
import HushCore
import SwiftUI

// Answer shapes (docs/design-guide.md §5.5): formula (SF Mono on a warm block, Copy inline), command (terminal
// block with a green $), fact (SF Rounded 40 with the working beside it), steps (grey number discs), prose (13.5).

struct ShapeBody: View {
    let shape: AnswerShape
    let copy: () -> Void
    let copied: Bool

    var body: some View {
        switch shape.shape {
        case .formula: formula
        case .command: command
        case .fact: fact
        case .steps: steps
        case .prose: prose
        }
    }

    private var title: some View {
        HStack(spacing: 6) {
            Text(shape.title).font(HushFont.cardTitle).lineLimit(2)
            // Only tags that tell you something ("Google Sheets", "zsh"), not a restatement of the shape.
            if let app = shape.app, !["command", "formula", "shell", "terminal", "cli"].contains(app.lowercased()) {
                HushTag(text: app, tone: app.lowercased().contains("sheets") || app.lowercased().contains("excel") ? .green : .grey)
            }
        }
    }

    private var formula: some View {
        VStack(alignment: .leading, spacing: 10) {
            title
            CodeBlock(text: shape.primary, style: .formula, copy: copy, copied: copied)
            parts
            if let note = shape.note { NoteLine(text: note) }
        }
    }

    private var command: some View {
        VStack(alignment: .leading, spacing: 10) {
            title
            CodeBlock(text: shape.primary, style: .terminal, copy: copy, copied: copied)
            if shape.destructive {
                Label("This can lose data. Check it before you run it.", systemImage: "exclamationmark.triangle.fill")
                    .font(HushFont.footer.weight(.medium)).foregroundStyle(Tone.orange.text)
            }
            parts
            if let note = shape.note { NoteLine(text: note) }
        }
    }

    @ViewBuilder private var parts: some View {
        if !shape.parts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(shape.parts.enumerated()), id: \.offset) { _, p in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(p.label)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(HushColor.lilacInk)
                            .frame(width: 112, alignment: .leading)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(p.detail).font(.system(size: 12.5)).foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var fact: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(shape.primary)
                .font(HushFont.number(shape.primary.count <= 10 ? 40 : shape.primary.count <= 22 ? 28 : 18))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let note = shape.note {
                Text(note).font(HushFont.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 9) {
            title
            ForEach(Array(shape.parts.enumerated()), id: \.offset) { i, p in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    NumberDisc(n: i + 1, tone: .waiting)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.label).font(HushFont.answerBody.weight(.medium))
                        if !p.detail.isEmpty {
                            Text(p.detail).font(HushFont.subtitle).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let note = shape.note { NoteLine(text: note) }
        }
    }

    private var prose: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AnswerView.styled(shape.primary))
                .font(HushFont.answerBody).lineSpacing(2).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let note = shape.note { NoteLine(text: note) }
        }
    }
}

/// 20 pt number disc: grey (a list, or a step not reached yet), blue (current), green ✓ (done).
struct NumberDisc: View {
    enum State { case waiting, current, done }
    let n: Int
    var tone: State = .waiting

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if tone == .done {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
            } else {
                Text("\(n)").font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(tone == .current ? .white : .secondary)
            }
        }
        .frame(width: 20, height: 20)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
    }

    private var fill: Color {
        switch tone {
        case .waiting: Color(nsColor: .labelColor).opacity(0.08)
        case .current: HushColor.working
        case .done: HushColor.done
        }
    }
}

struct CodeBlock: View {
    enum Style { case formula, terminal }
    let text: String
    let style: Style
    let copy: () -> Void
    let copied: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if style == .terminal { Text("$").foregroundStyle(Color(nsColor: .systemGreen)) }
                Text(text).foregroundStyle(style == .terminal ? Color.white.opacity(0.92) : .primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: copy) {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(copied ? HushColor.done : (style == .terminal ? Color.white.opacity(0.6) : .secondary))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fill: Color {
        style == .terminal ? Color(hex: 0x1E1C23)
            : Color(light: NSColor(hex: 0xF2EFEA), dark: NSColor.white.withAlphaComponent(0.07))
    }
}

struct NoteLine: View {
    let text: String
    var body: some View {
        Text(AnswerView.styled(text)).font(HushFont.footer).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
