import HushCore
import SwiftUI

/// The onboarding card. One layout, seven steps: progress, a title in Hush's voice-less style (plain UI words),
/// the step's content, and a footer with Back · Skip setup · the primary action.
struct OnboardingView: View {
    @ObservedObject var controller: OnboardingController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if controller.step != .arrival { ProgressDots(step: controller.step) }
                Spacer()
                if controller.step < .goodbye {
                    Button("Skip setup", action: controller.skipAll).buttonStyle(HushPill(kind: .quiet))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(HushFont.onboardingTitle).fixedSize(horizontal: false, vertical: true)
                if let sub = subtitle {
                    Text(sub).font(HushFont.subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            content
                .transition(.opacity)
                .id(controller.step)
            footer
        }
        .animation(HushMotion.reduceMotion ? nil : .smooth(duration: 0.25), value: controller.step)
        .onChange(of: controller.step) { _, _ in controller.reposition() }
        .onChange(of: controller.progress) { _, _ in controller.reposition() }
    }

    // MARK: copy

    private var title: String {
        switch controller.step {
        case .arrival: "Hi, I'm Hush."
        case .look: "Make me yours"
        case .question: "What do you mostly do on your Mac?"
        case .sayHi: "Say hi"
        case .connect: "A few helpful connections"
        case .quiet: "How often may I tap the glass?"
        case .goodbye: "That's it. I'll be right down here."
        }
    }

    private var subtitle: String? {
        switch controller.step {
        case .arrival: "I live at the edge of your screen and stay quiet unless something really matters. Let's set me up; it takes about two minutes."
        case .look: "Pick what feels like you. You can change this any time from the menu bar."
        case .question: "Pick any. I'll switch on what's useful and leave the rest off."
        case .sayHi: "Three tiny things, so you know how to reach me."
        case .connect: "Each one is optional. Nothing leaves your Mac unless you ask a question."
        case .quiet: "Interrupts are for things that can't wait: a meeting in 2 minutes, a VIP. Everything else waits politely."
        case .goodbye: "Tonight I'll tuck in and tell you what I held back. Find me in the menu bar (the eyes) for settings."
        }
    }

    // MARK: content

    @ViewBuilder private var content: some View {
        switch controller.step {
        case .arrival: EmptyView()
        case .look: LookPicker(controller: controller)
        case .question: PersonaPicker(controller: controller)
        case .sayHi: SayHiList(done: controller.progress.sayHi)
        case .connect: ConnectList(controller: controller)
        case .quiet: QuietPicker(controller: controller)
        case .goodbye: GoodbyeSummary(controller: controller)
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack(spacing: 8) {
            if controller.step > .arrival && controller.step < .goodbye {
                Button("Back", action: controller.back).buttonStyle(HushPill(kind: .quiet))
            }
            Spacer()
            Button(primary, action: controller.next)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(HushPill(kind: primaryIsSecondary ? .secondary : .primary, height: 30))
        }
    }

    /// Say hi: Next stays secondary until one of the three tries is done.
    private var primaryIsSecondary: Bool { controller.step == .sayHi && controller.progress.sayHi.isEmpty }

    private var primary: String {
        switch controller.step {
        case .arrival: "Let's go"
        case .sayHi: controller.progress.sayHi.isEmpty ? "Skip" : "Next"
        case .goodbye: "Done"
        default: "Next"
        }
    }
}

// MARK: - Pieces

struct ProgressDots: View {
    let step: OnboardingStep
    var body: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s <= step ? HushColor.primaryFill : Color(nsColor: .labelColor).opacity(0.15))
                    .frame(width: s == step ? 16 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.3), value: step)
    }
}

struct LookPicker: View {
    @ObservedObject var controller: OnboardingController

    var body: some View {
        let look = controller.look
        VStack(alignment: .leading, spacing: 10) {
            row("Body", CharacterLook.bodies, look.body) { v in controller.setLook { $0.body = v } }
            HStack(spacing: 8) {
                Text("Colour").font(HushFont.footer.weight(.medium)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                ForEach(Wardrobe.freeColours, id: \.self) { p in
                    Button { controller.setLook { $0.palette = p } } label: {
                        Circle().fill(Self.swatch[p] ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(look.palette == p ? Color.primary : .clear, lineWidth: 2).padding(-3))
                    }
                    .buttonStyle(.plain).help(p.capitalized)
                }
            }
            row("Topper", CharacterLook.toppers, look.topper) { v in controller.setLook { $0.topper = v } }
            row("Wear", ["none"] + Self.wears, Self.wears.first { look.outfit.values.contains($0) } ?? "none") { v in
                controller.setLook { l in
                    l.outfit = [:]
                    if let p = Wardrobe.piece(v) { l.outfit[p.slot.rawValue] = p.id }
                }
            }
            Button(action: controller.surpriseMe) { Text("🎲 Surprise me") }
                .buttonStyle(HushPill(kind: .secondary))
        }
    }

    /// A few free pieces for step 2 (the rest live in Character ▸ Wardrobe).
    static let wears = ["scarf", "cap", "glasses", "headphones"]

    static let swatch: [String: Color] = [
        "oat": Color(red: 0.96, green: 0.85, blue: 0.65), "mint": Color(red: 0.78, green: 0.91, blue: 0.82),
        "lilac": Color(red: 0.86, green: 0.82, blue: 0.96), "sky": Color(red: 0.76, green: 0.87, blue: 0.96),
        "rose": Color(red: 0.97, green: 0.80, blue: 0.78),
    ]

    private func row(_ label: String, _ options: [String], _ current: String, pick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 5) {
            Text(label).font(HushFont.footer.weight(.medium)).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            ForEach(options, id: \.self) { o in
                Button { pick(o) } label: {
                    Text(o.capitalized).font(.system(size: 11.5, weight: o == current ? .semibold : .regular))
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(o == current ? HushColor.primaryFill : HushColor.quietFill, in: Capsule())
                        .foregroundStyle(o == current ? HushColor.primaryText : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 2×2 multi-select tiles; each says what it switches on.
struct PersonaPicker: View {
    @ObservedObject var controller: OnboardingController
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Persona.allCases, id: \.self) { p in
                let on = controller.progress.personas.contains(p)
                Button { controller.togglePersona(p) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: p.symbol).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? AnyShapeStyle(HushColor.lilacInk) : AnyShapeStyle(.tertiary))
                        }
                        Text(p.title).font(HushFont.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        Text(p.subtitle).font(HushFont.footer).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                    .background(on ? HushColor.lilacTint : HushColor.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(on ? HushColor.lilacInk.opacity(0.5) : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SayHiList: View {
    let done: Set<String>
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            item("hover", "Move your pointer over me", "I'll pop up to see you", "cursorarrow.motionlines")
            item("pat", "Press and hold on me", "That's a pat. I like those", "hand.raised")
            item("drag", "Drag me where you'd like me to live", "Anywhere along the bottom edge", "arrow.up.and.down.and.arrow.left.and.right")
        }
    }
    private func item(_ key: String, _ title: String, _ sub: String, _ icon: String) -> some View {
        let ok = done.contains(key)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(ok ? Tone.green.fill : HushColor.quietFill).frame(width: 28, height: 28)
                Image(systemName: ok ? "checkmark" : icon).font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ok ? Tone.green.text : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(HushFont.body.weight(.medium))
                Text(sub).font(HushFont.footer).foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.3), value: ok)
    }
}

struct ConnectList: View {
    @ObservedObject var controller: OnboardingController
    var body: some View {
        VStack(spacing: 8) {
            ForEach(controller.preset.connect, id: \.self) { c in
                row(c)
            }
        }
        .onAppear { controller.refreshConnected() }
    }

    @ViewBuilder private func row(_ c: ConnectStep) -> some View {
        let done = controller.progress.connected.contains(c)
        let declined = controller.progress.declined.contains(c)
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: icon(c), tone: .grey, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(c)).font(HushFont.body.weight(.semibold))
                Text(detail(c)).font(HushFont.footer).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if done {
                Label("Connected", systemImage: "checkmark.circle.fill").labelStyle(.titleAndIcon)
                    .font(HushFont.footer.weight(.semibold)).foregroundStyle(Tone.green.text)
            } else if c == .askHotkey {
                Text("⌘⇧H").font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            } else {
                Button(declined ? "Try again" : action(c)) { controller.connect(c) }.buttonStyle(HushPill(kind: .secondary, height: 26))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(HushColor.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func icon(_ c: ConnectStep) -> String {
        switch c { case .calendar: "calendar"; case .claudeCode: "terminal"; case .askHotkey: "sparkle" }
    }
    private func title(_ c: ConnectStep) -> String {
        switch c { case .calendar: "Meeting reminders"; case .claudeCode: "Watch my Claude Code runs"; case .askHotkey: "Ask me anything" }
    }
    private func detail(_ c: ConnectStep) -> String {
        switch c {
        case .calendar: "I hold up a little clock 10 minutes before a meeting, and come closer at 2. Reads your Calendar app."
        case .claudeCode: "I think while your agents work and bring an envelope when a long run finishes. You'll see the exact settings change first."
        case .askHotkey: "Press it now from any app. Quick answers right here, bigger questions go to ChatGPT or Claude."
        }
    }
    private func action(_ c: ConnectStep) -> String {
        switch c { case .calendar: "Connect"; case .claudeCode: "Connect"; case .askHotkey: "" }
    }
}

/// Four big choices (1 · 3 · 5 · 8: rarely, calm, usual, busy), then the quiet hours line.
struct QuietPicker: View {
    @ObservedObject var controller: OnboardingController
    static let choices: [(Int, String)] = [(1, "rarely"), (3, "calm"), (5, "usual"), (8, "busy")]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Self.choices, id: \.0) { n, label in
                    let on = Int(controller.cap.rounded()) == n
                    Button { controller.cap = Double(n) } label: {
                        VStack(spacing: 2) {
                            Text("\(n)").font(HushFont.number(26))
                            Text(label).font(HushFont.footer)
                        }
                        .foregroundStyle(on ? HushColor.primaryText : .primary)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(on ? HushColor.primaryFill : HushColor.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Interrupts a day, at most.").font(HushFont.footer).foregroundStyle(.secondary)
            Toggle(isOn: $controller.quietHours) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quiet hours, 22:00 to 07:00").font(HushFont.body.weight(.medium))
                    Text("Nothing but meeting reminders overnight").font(HushFont.footer).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }
}

struct GoodbyeSummary: View {
    @ObservedObject var controller: OnboardingController
    var body: some View {
        let p = controller.progress
        VStack(alignment: .leading, spacing: 6) {
            line("At most \(Int(controller.cap.rounded())) interrupts a day" + (controller.quietHours ? ", quiet overnight" : ""), "bell.slash")
            if p.connected.contains(.calendar) { line("Meeting reminders on", "calendar") }
            if p.connected.contains(.claudeCode) { line("Watching your Claude Code runs", "terminal") }
            line("Ask me anything with ⌘⇧H", "sparkle")
            if controller.preset.perch { line("I might sit on a window when you're away", "macwindow") }
        }
    }
    private func line(_ t: String, _ icon: String) -> some View {
        Label { Text(t).font(HushFont.subtitle) } icon: { Image(systemName: icon).foregroundStyle(HushColor.lilacInk) }
    }
}
