import AppKit
import HushCore
import HushMac
import SwiftUI

/// Settings (docs/design-guide.md §5.10): a standard window with a sidebar. General, Character, Home spot, Perch and
/// moods, Ask Hush, Browser tasks, Connections, Setup, Developer.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", character = "Character", home = "Home spot", perch = "Perch and moods"
    case ask = "Ask Hush", browser = "Browser tasks", connections = "Connections", setup = "Setup", developer = "Developer"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .character: "face.smiling"
        case .home: "house"
        case .perch: "macwindow"
        case .ask: "bolt"
        case .browser: "safari"
        case .connections: "link"
        case .setup: "checklist"
        case .developer: "hammer"
        }
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let model: SettingsModel
    private let selection = SelectionBox()

    final class SelectionBox: ObservableObject { @Published var section: SettingsSection? = .general }

    init(model: SettingsModel) { self.model = model }

    func show(_ section: SettingsSection = .general) {
        selection.section = section
        model.reload()
        let w = window ?? make()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    private func make() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "Hush Settings"
        w.isReleasedWhenClosed = false
        w.toolbarStyle = .unified
        w.contentView = NSHostingView(rootView: SettingsView(model: model, selection: selection))
        w.center()
        return w
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var selection: SettingsWindowController.SelectionBox

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection.section) { s in
                Label(s.rawValue, systemImage: s.symbol).tag(s)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(190)
        } detail: {
            Form { section(selection.section ?? .general) }
                .formStyle(.grouped)
                .navigationTitle(selection.section?.rawValue ?? "General")
        }
        .frame(minWidth: 640, minHeight: 440)
    }

    @ViewBuilder private func section(_ s: SettingsSection) -> some View {
        switch s {
        case .general: general
        case .character: character
        case .home: home
        case .perch: perch
        case .ask: ask
        case .browser: browser
        case .connections: connections
        case .setup: setup
        case .developer: developer
        }
    }

    // MARK: sections

    @ViewBuilder private var general: some View {
        Section {
            Picker("Interrupts a day, at most", selection: model.interruptsPerDay) {
                ForEach([1, 3, 5, 8], id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Quiet hours, 22:00 to 07:00", isOn: model.quietHours)
        } footer: { Text("Only meeting times, VIPs and your own rules can interrupt. Everything else waits.") }
        Section {
            Picker("Heads-up before a meeting", selection: model.meetingHeadsUp) {
                ForEach([3, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
            }
            Picker("Come out and wait", selection: model.meetingComeOut) {
                ForEach([1, 2, 3], id: \.self) { Text("\($0) min before").tag($0) }
            }
        } footer: { Text("Hush is its own window, so Focus and Do Not Disturb don't hide it. With a video link, one click on Hush joins.") }
        Section {
            Toggle("Open at login", isOn: model.openAtLogin)
            Toggle("Hide in full-screen apps", isOn: model.hideInFullScreen)
            Toggle("Hide from screen shares and screenshots", isOn: model.hiddenFromCapture)
            Toggle("Show a count in the menu bar", isOn: model.showCount)
        }
    }

    @ViewBuilder private var character: some View {
        Section("Look") {
            Picker("Body", selection: model.binding({ model.look.body }, { v in model.app.setLook { $0.body = v } })) {
                ForEach(CharacterLook.bodies, id: \.self) { Text($0.capitalized).tag($0) }
            }
            Picker("Colour", selection: model.binding({ model.look.palette }, { v in model.app.setLook { $0.palette = v } })) {
                ForEach(CharacterLook.palettes, id: \.self) { Text($0.capitalized).tag($0) }
            }
            Picker("Eyes", selection: model.binding({ model.look.eyes }, { v in model.app.setLook { $0.eyes = v } })) {
                ForEach(CharacterLook.eyeStyles, id: \.self) { Text($0.capitalized).tag($0) }
            }
            Picker("Topper", selection: model.binding({ model.look.topper }, { v in model.app.setLook { $0.topper = v } })) {
                ForEach(CharacterLook.toppers, id: \.self) { Text($0.capitalized).tag($0) }
            }
        }
        Section {
            ForEach([WearSlot.head, .face, .neck, .carry], id: \.self) { slot in
                Picker(slot.displayName, selection: model.wear(slot)) {
                    Text("None").tag("none")
                    ForEach(Wardrobe.pieces(in: slot).filter { $0.source != .rare || model.app.rare.found.contains($0.id) }) { p in
                        Text(p.name).tag(p.id)
                    }
                }
            }
        } header: { Text("Wearing") } footer: { Text("Everything Hush does is free. Pieces only change how it looks.") }
        Section {
            Button("Open the wardrobe…") { model.app.openWardrobe?() }
        }
        Section {
            RareFindsGrid(state: model.app.rare.state, body_: model.look.body)
        } header: { Text("Rare finds") } footer: { Text("Hush finds these on its own, very rarely. Found pieces can be worn any day.") }
    }

    @ViewBuilder private var home: some View {
        Section {
            Picker("Home spot", selection: model.homeX) {
                Text("Bottom left").tag(0.04)
                Text("Bottom centre").tag(0.5)
                Text("Bottom right").tag(0.92)
            }
            .pickerStyle(.radioGroup)
        } footer: { Text("You can also drag Hush anywhere along the bottom edge.") }
    }

    @ViewBuilder private var perch: some View {
        Section {
            Toggle("Perch on windows when idle", isOn: model.perch)
            Toggle("Moods: gets grumpy when ignored", isOn: model.moods)
        }
    }

    @ViewBuilder private var ask: some View {
        Section {
            Picker("Open long questions in", selection: model.handoff) {
                ForEach(AskLane.Provider.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        } footer: { Text("Press ⌘⇧H anywhere. Quick answers here, longer ones in your assistant.") }
        Section {
            Toggle("Rework what I copy", isOn: model.pouch)
        } footer: {
            Text("Copy some text and my cheeks fill up. Click me to make it simpler, shorter or into bullets, then paste. I read what you copied only when you click, on this Mac.")
        }
        Section {
            Toggle("Smart routing", isOn: model.smartRouting)
            if model.learnedCount > 0 {
                HStack {
                    Text("Learned from your corrections: \(model.learnedCount)")
                    Spacer()
                    Button("Forget") { model.forgetLearnedRoutes() }.buttonStyle(.borderless)
                }
            }
        } footer: {
            Text("When the route isn't clear, Hush asks a quick model to choose (about $0.0003). When you change a route before sending, Hush remembers it, on this Mac.")
        }
        Section("Models") {
            ForEach([LaneID.quick, .repo, .summarise, .route], id: \.self) { lane in
                Picker(lane.displayName, selection: model.model(lane)) {
                    ForEach(ModelAlias.allCases, id: \.self) { m in
                        Text(m.displayName + (m.rawValue == LaneRegistry.defaultSpec(lane).model ? " · default" : "")).tag(m.rawValue)
                    }
                }
            }
        }
        Section("Repos Hush may read") {
            ForEach(model.repos, id: \.self) { p in
                HStack {
                    Text(URL(fileURLWithPath: p).lastPathComponent)
                    Spacer()
                    Button("Remove") { model.removeRepo(p) }.buttonStyle(.borderless)
                }
            }
            Button("Allow a repo…") { model.addRepo() }
        }
        Section {
            Toggle("While you were away digest", isOn: model.binding({ model.digestOn }, { _ in model.toggleDigest() }))
            Button("What I've learned…") { model.app.showRules() }
            Button("History…") { model.app.ask.showHistory() }
        }
    }

    @ViewBuilder private var browser: some View {
        Section {
            Toggle("Browser tasks (beta)", isOn: model.browserTasks)
            if model.browserTasks.wrappedValue {
                Picker("Run in", selection: model.taskBrowser) {
                    Text("Automatic").tag("auto")
                    ForEach(model.browsersWithExtension, id: \.self) { Text($0.displayName).tag($0.rawValue) }
                }
            }
        } footer: {
            Text("You approve a plan first. It's told to ask before sending, buying or deleting, and never to type passwords. Needs the Claude extension signed in with the same account as Claude Code.")
        }
    }

    @ViewBuilder private var connections: some View {
        Section {
            ForEach(model.connections) { c in ConnectionRow(model: model, c: c) }
        } footer: {
            Text("Nothing leaves your Mac unless you ask.")
        }
        Section {
            Toggle("Let Apple Intelligence read the first lines of each mail", isOn: model.mailSnippets)
        } footer: {
            Text("Off: it judges mail by sender and subject only. On: it also reads the first 400 characters, on this Mac, never stored. On catches a few more replies that ask you something.")
        }
    }

    @ViewBuilder private var setup: some View {
        Section {
            if model.setupLeft.isEmpty { Text("All set up.").foregroundStyle(.secondary) }
            ForEach(model.setupLeft, id: \.self) { step in
                HStack {
                    Text(model.setupTitle(step))
                    Spacer()
                    Button("Do it") { model.doSetup(step) }
                }
            }
        }
        Section {
            Button("Replay the intro") { model.replayIntro() }
            if !model.tipsOff { Button("Turn off first-week tips") { model.turnOffTips() } }
        }
    }

    @ViewBuilder private var developer: some View {
        Section("Simulate") {
            Button("Mail: ordinary") { model.app.simulate(.ordinary) }
            Button("Mail: someone asks for something") { model.app.simulate(.ask) }
            Button("Mail: VIP") { model.app.simulate(.vip) }
            Button("Mail: newsletter (dropped)") { model.app.simulate(.bulk) }
            Button("Meeting in 10 min") { model.app.simulateMeeting(inMinutes: 10) }
            Button("Meeting in 2 min") { model.app.simulateMeeting(inMinutes: 2) }
        }
        Section("Play") {
            Button("Tuck in now") { model.app.antics.tuckIn() }
            Button("Weekly card") { model.app.showHeldBack(.week) }
            Button("Inbox zero") { model.app.celebrateInboxZero() }
            Button("Command window") { model.app.playCommandWindow() }
            Button("Show data folder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: HushStore.defaultPath())])
            }
        }
    }
}

struct ConnectionRow: View {
    @ObservedObject var model: SettingsModel
    let c: SettingsModel.Connection

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: model.symbol(c), tone: model.status(c) == nil ? .grey : (c == .mail ? .grey : .green), size: 22)
            Text(model.title(c))
            Spacer()
            if let s = model.status(c) {
                if c == .mail {
                    Text(s).font(HushFont.footer).foregroundStyle(.secondary)
                } else {
                    Label(s, systemImage: "checkmark").font(HushFont.footer.weight(.medium)).foregroundStyle(Tone.green.text)
                    if model.needsUpdate(c) {
                        Button("Update") { model.connect(c) }.buttonStyle(.borderless).font(HushFont.footer)
                            .help("Lets Hush say what your agent is asking for, and notice runs that stop on an error")
                    }
                    if c == .claude || c == .codex || c == .appleIntelligence {
                        Button(c == .appleIntelligence ? "Turn off" : "Remove") { model.disconnect(c) }
                            .buttonStyle(.borderless).font(HushFont.footer)
                    }
                }
            } else if let note = model.note(c) {
                Text(note).font(HushFont.footer).foregroundStyle(.secondary)
                if note == "Off in System Settings" {
                    Button("Open") { model.connect(c) }.buttonStyle(.borderless).font(HushFont.footer)
                }
            } else {
                Button(model.connectTitle(c)) { model.connect(c) }
            }
        }
    }
}
