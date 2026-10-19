import AppKit
import HushCore
import HushMac
import WebKit

/// FR-13: the user's chosen look. Mirrors the layer names in assets/character (docs/design-guide.md §6, 6a).
/// What Hush wears is one piece per slot (head, face, neck, carry, buddy); see HushCore `Wardrobe`.
struct CharacterLook: Codable, Equatable {
    var body = "blob"
    var palette = "oat"
    var eyes = "round"
    var topper = "leaf"
    /// Slot raw value → piece id.
    var outfit: [String: String] = [:]
    /// Rare finds (D6) worn for today only, over the same slot. Not saved.
    var todayOutfit: [String: String] = [:]

    static let bodies = ["blob", "bean", "square"]
    static let palettes = Wardrobe.freeColours + Wardrobe.packColours
    static let eyeStyles = ["round", "oval", "pebble"]
    static let toppers = ["none", "antenna", "ears", "leaf"]

    init() {}

    func wearing(_ slot: WearSlot) -> String? { todayOutfit[slot.rawValue] ?? outfit[slot.rawValue] }

    /// Rig layers to draw, in slot order.
    var wearLayers: [String] {
        Wardrobe.layers(for: Dictionary(uniqueKeysWithValues: WearSlot.allCases.compactMap { s in wearing(s).map { (s, $0) } }))
    }

    enum CodingKeys: String, CodingKey { case body, palette, eyes, topper, outfit, accessory }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? body
        palette = try c.decodeIfPresent(String.self, forKey: .palette) ?? palette
        eyes = try c.decodeIfPresent(String.self, forKey: .eyes) ?? eyes
        topper = try c.decodeIfPresent(String.self, forKey: .topper) ?? topper
        if let o = try c.decodeIfPresent([String: String].self, forKey: .outfit) {
            outfit = o.filter { Wardrobe.piece($0.value)?.slot.rawValue == $0.key }
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .accessory),
                  let piece = Wardrobe.piece(legacy) {
            // Before slots: one "accessory" (scarf, cap or glasses).
            outfit = [piece.slot.rawValue: piece.id]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(body, forKey: .body)
        try c.encode(palette, forKey: .palette)
        try c.encode(eyes, forKey: .eyes)
        try c.encode(topper, forKey: .topper)
        try c.encode(outfit, forKey: .outfit)
    }

    /// What the renderer page reads (`hush.setLook`).
    var rendererJSON: String {
        let o: [String: Any] = ["body": body, "palette": palette, "eyes": eyes, "topper": topper, "wear": wearLayers]
        return (try? JSONSerialization.data(withJSONObject: o)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}

/// Anything that can draw Hush. Today: the SVG rig in a web view. Later: a Rive state machine
/// (inputs: state, body, palette, eyes, topper, accessory, gaze), with no changes to the controller.
@MainActor
protocol CharacterRenderer: AnyObject {
    var view: NSView { get }
    var onEvent: ((RendererEvent) -> Void)? { get set }
    /// On-screen height of the character in points (PRD minimum 64).
    var characterHeight: CGFloat { get }
    /// `duck`: the hide pose because you're typing (lowered peek, eyes showing), not a call (gone).
    func show(_ state: CharacterState, fromEdge: Bool, duck: Bool)
    func apply(_ look: CharacterLook)
    func setDarkDesktop(_ dark: Bool)
    /// Cursor position in the view's top-left-origin coordinates.
    func pointer(at p: CGPoint)
    func react(_ r: Reaction)
}

@MainActor
final class WebCharacterRenderer: NSObject, CharacterRenderer, WKScriptMessageHandler {
    private let webView: WKWebView
    private var ready = false
    private var pending: [String] = []
    private var lastPointer: CGPoint?
    var onEvent: ((RendererEvent) -> Void)?
    let characterHeight: CGFloat

    var view: NSView { webView }

    init(characterHeight: CGFloat = 104) throws {
        self.characterHeight = characterHeight
        let config = WKWebViewConfiguration()
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(
            source: "window.HUSH_DATA = \(try Assets.rendererData());",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = content
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        content.add(WeakHandler(self), name: "hush")
        // Transparent page over the desktop. KVC is the long-standing way to do this on macOS.
        webView.setValue(false, forKey: "drawsBackground")
        let html = try Assets.rendererPage()
        webView.loadHTMLString(html, baseURL: nil)
        js("hush.setLook({height: \(Int(characterHeight))})")
    }

    func show(_ state: CharacterState, fromEdge: Bool, duck: Bool) {
        js("hush.setState('\(state.rawValue)', {fromEdge: \(fromEdge), duck: \(duck)})")
    }

    func apply(_ look: CharacterLook) {
        js("hush.setLook(\(look.rendererJSON))")
    }

    func setDarkDesktop(_ dark: Bool) { js("hush.setDark(\(dark))") }

    func pointer(at p: CGPoint) {
        // Skip sub-pixel jitter; this runs on a 30 Hz timer.
        if let l = lastPointer, abs(l.x - p.x) < 1, abs(l.y - p.y) < 1 { return }
        lastPointer = p
        js("hush.pointer(\(Int(p.x)), \(Int(p.y)))")
    }

    func react(_ r: Reaction) {
        switch r {
        case .hover(let on): js("hush.hover(\(on))")
        case .press(let on): js("hush.press(\(on))")
        case .pat(let on): js("hush.pat(\(on))")
        case .poke: js("hush.poke()")
        case .lift: js("hush.lift()")
        case .swing(let vx): js("hush.swing(\(Int(vx / 60)))")
        case .land(let k): js("hush.land(\(String(format: "%.2f", k)))")
        case .cheeks: js("hush.cheeks()")
        case .blow: js("hush.blow()")
        case .chew(let on): js("hush.chew(\(on))")
        case .saver(let on): js("hush.setSaver(\(on))")
        case .askPat(let a): js("hush.askPat('\(a.rawValue)')")
        case .proud: js("hush.proud()")
        case .rareFirst(let id): js("hush.rareFirst('\(id)')")
        case .boxPose(let p): js("hush.boxPose(\(p.map { "'\($0)'" } ?? "null"))")
        case .flash: js("hush.flash()")
        case .woozy: js("hush.woozy()")
        case .flinch(let dx): js("hush.flinch(\(Int(dx)))")
        case .perk: js("hush.perk()")
        case .morning: js("hush.morning()")
        case .dance: js("hush.dance()")
        case .tuckIn: js("hush.tuckIn()")
        case .mode(let name, let on): js("hush.setMode('\(name)', \(on))")
        case .perchDoze(let on): js("hush.perchDoze(\(on))")
        case .mood(let stage): js("hush.setMood(\(stage))")
        case .inboxZero: js("hush.inboxZero()")
        case .commandWindow: js("hush.commandWindow()")
        case .jump: js("hush.jump()")
        case .visible(let on): js("hush.setVisible(\(on))")
        case .debugCalm(let m): js(m == "diag" ? "hush.diag()" : "hush.debugCalm('\(m)')")
        case .perchLand: js("hush.perchLand()")
        case .wave: js("hush.waveOff()")
        case .handOver: js("hush.handOver()")
        case .sorry: js("hush.sorry()")
        }
    }

    private func js(_ source: String) {
        guard ready else { pending.append(source); return }
        webView.evaluateJavaScript(source, completionHandler: nil)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            ready = true
            pending.forEach { webView.evaluateJavaScript($0, completionHandler: nil) }
            pending.removeAll()
            onEvent?(.ready)
        case "log":
            DiagnosticsLog.write("renderer: \(body["message"] as? String ?? "?")")
        case "error":
            DiagnosticsLog.write("renderer error: \(body["message"] as? String ?? "?")")
        case "bbox":
            let n = { (k: String) in CGFloat((body[k] as? NSNumber)?.doubleValue ?? 0) }
            onEvent?(.bounds(CGRect(x: n("x"), y: n("y"), width: n("w"), height: n("h"))))
        default:
            break
        }
    }
}

/// WKUserContentController retains its handlers; this breaks the cycle.
@MainActor
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}
