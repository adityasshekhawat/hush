import AppKit
import HushCore
import HushMac
import SwiftUI

/// The flag rail (v1 art, ADR-030): agent sessions waiting behind the one Hush holds stand as flags on the bottom edge,
/// left of Hush's spot, newest nearest. Click one to bring it forward and open its card. Static art, no animation:
/// it costs nothing while it stands. Click-through everywhere except the flags themselves.
@MainActor
final class FlagRailController {
    private let panel: NSPanel
    private let model = FlagRailModel()
    /// The flags' hit areas in screen coordinates.
    private var hitRects: [(id: String, rect: NSRect)] = []
    private var layout: (flags: [FlagRail.Flag], more: Int) = ([], 0)
    var onOpen: ((String) -> Void)?
    /// Points per art unit (the 160 × 146 canvas at Hush's size).
    let unit: CGFloat
    /// Stick to stick, in points (art notes).
    static let spacing: CGFloat = 64

    init(characterHeight: CGFloat) {
        unit = characterHeight / 100
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        let view = FlagRailView(model: model, unit: unit) { [weak self] id in self?.onOpen?(id) }
        panel.contentView = NSHostingView(rootView: view)
    }

    var window: NSWindow { panel }

    func update(_ l: (flags: [FlagRail.Flag], more: Int)) {
        guard l.flags != layout.flags || l.more != layout.more else { return }
        if l.flags.count > layout.flags.count + (layout.more > 0 ? 1 : 0) {
            DiagnosticsLog.write("flags: \(l.flags.count) on the rail\(l.more > 0 ? " + \(l.more) more" : "")")
        }
        layout = l
        model.flags = l.flags
        model.more = l.more
        relayout()
    }

    /// `home`: Hush's panel at its home spot; `floor`: the screen edge Hush stands on.
    func place(home: NSRect, floor: CGFloat, hidden: Bool) {
        self.home = home
        self.floor = floor
        self.hidden = hidden
        relayout()
    }

    private var home: NSRect = .zero
    private var floor: CGFloat = 0
    private var hidden = true

    private func relayout() {
        let count = layout.flags.count + (layout.more > 0 ? 1 : 0)
        guard count > 0, !hidden, home.width > 0 else {
            if panel.isVisible { panel.orderOut(nil) }
            hitRects = []
            return
        }
        // The nearest stick stands clear of Hush's body (canvas x 38 in its panel) with room for the pennant (52).
        let nearestStick = home.minX + (38 - 58) * unit
        let width = Self.spacing * CGFloat(count - 1) + 66 * unit
        let height = 108 * unit
        let frame = NSRect(x: nearestStick - Self.spacing * CGFloat(count - 1) - 12 * unit, y: floor - 4 * unit,
                           width: width, height: height)
        panel.setFrame(frame, display: true)
        model.count = count
        // Slot 0 is nearest Hush (rightmost).
        hitRects = (0..<count).map { i in
            let stick = nearestStick - Self.spacing * CGFloat(i)
            let id = i < layout.flags.count ? layout.flags[i].decisionID : (layout.flags.last?.decisionID ?? "")
            return (id, NSRect(x: stick - 8 * unit, y: floor, width: 62 * unit, height: 90 * unit))
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    /// Click-through except over a flag (called from the pointer poll).
    func pointer(_ m: NSPoint) {
        guard panel.isVisible else { return }
        let over = hitRects.contains { $0.rect.contains(m) }
        if panel.ignoresMouseEvents == over { panel.ignoresMouseEvents = !over }
    }

    func setAccent(_ hex: String?) { model.accent = hex }
}

@MainActor
final class FlagRailModel: ObservableObject {
    @Published var flags: [FlagRail.Flag] = []
    @Published var more = 0
    @Published var count = 0
    @Published var accent: String?
}

/// Right to left: the newest flag stands nearest Hush.
private struct FlagRailView: View {
    @ObservedObject var model: FlagRailModel
    let unit: CGFloat
    let open: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: FlagRailController.spacing - 66 * unit) {
            if model.more > 0, let oldest = model.flags.last {
                FlagArt(file: "flag-bundle", text: "+\(model.more) more", accent: model.accent, unit: unit,
                        viewBox: CGRect(x: -14, y: -62, width: 54, height: 66), textRect: CGRect(x: 11, y: -14, width: 22, height: 10), textSize: 7)
                    .frame(width: 66 * unit, height: 108 * unit, alignment: .bottomLeading)
                    .onTapGesture { open(oldest.decisionID) }
                    .help("\(model.more) more sessions waiting")
            }
            ForEach(model.flags.reversed(), id: \.decisionID) { f in
                FlagArt(file: "flag-\(f.kind.rawValue)", text: f.project, accent: model.accent, unit: unit,
                        viewBox: CGRect(x: -12, y: -104, width: 66, height: 108), textRect: CGRect(x: 5, y: -67, width: 38, height: 12), textSize: 8)
                    .frame(width: 66 * unit, height: 108 * unit, alignment: .bottomLeading)
                    .onTapGesture { open(f.decisionID) }
                    .help(Self.help(f))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    static func help(_ f: FlagRail.Flag) -> String {
        switch f.kind {
        case .done: "\(f.project) finished"
        case .needs: "\(f.project) needs you"
        case .careful: "\(f.project) needs a careful look"
        case .error: "\(f.project) stopped"
        }
    }
}

/// One edge file, drawn at Hush's scale, with the app's words in the art's blank area.
private struct FlagArt: View {
    let file: String
    let text: String
    let accent: String?
    let unit: CGFloat
    let viewBox: CGRect
    let textRect: CGRect
    let textSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let img = Self.image(file, accent: accent) {
                Image(nsImage: img).resizable().frame(width: viewBox.width * unit, height: viewBox.height * unit)
            }
            Text(text)
                .font(.system(size: textSize * unit, weight: .semibold))
                .foregroundStyle(Color(red: 0x2D / 255, green: 0x2A / 255, blue: 0x35 / 255))
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: textRect.width * unit, height: textRect.height * unit)
                .offset(x: (textRect.minX - viewBox.minX) * unit, y: (textRect.minY - viewBox.minY) * unit)
        }
        .frame(width: viewBox.width * unit, height: viewBox.height * unit)
        .contentShape(Rectangle())
    }

    private static var cache: [String: NSImage] = [:]

    static func image(_ file: String, accent: String?) -> NSImage? {
        let key = file + (accent ?? "")
        if let c = cache[key] { return c }
        let url = Assets.root.appendingPathComponent("character/edge/\(file).svg")
        guard var svg = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        if let accent { svg = svg.replacingOccurrences(of: "#E8876A", with: accent) }
        let img = NSImage(data: Data(svg.utf8))
        cache[key] = img
        return img
    }
}
