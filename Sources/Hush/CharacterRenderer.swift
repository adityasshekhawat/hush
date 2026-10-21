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
        // headWear: the hat's layers, which the energy saver's nightcap takes the place of.
        let hat = wearing(.head).flatMap { Wardrobe.piece($0)?.layers } ?? []
        let o: [String: Any] = ["body": body, "palette": palette, "eyes": eyes, "topper": topper, "wear": wearLayers, "headWear": hat]
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
    /// `variant`: what kind of thing the state is about (v1 art: "needs", "careful", "error", "meeting", "door",
    /// "late", "mail"), with the words the art shows (`card`, `flag`, …).
    func show(_ state: CharacterState, fromEdge: Bool, duck: Bool, variant: String?, labels: [String: String])
    func apply(_ look: CharacterLook)
    func setDarkDesktop(_ dark: Bool)
    /// Cursor position in the view's top-left-origin coordinates.
    func pointer(at p: CGPoint)
    func react(_ r: Reaction)
    /// This Hush in a pose and expression, as a still picture (the menu bar panel's avatar). nil before it's ready.
    func portrait(pose: String, expression: String) async -> NSImage?
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

    func show(_ state: CharacterState, fromEdge: Bool, duck: Bool, variant: String?, labels: [String: String]) {
        let o: [String: Any] = ["fromEdge": fromEdge, "duck": duck, "variant": variant ?? "", "labels": labels]
        js("hush.setState('\(state.rawValue)', \(Self.json(o)))")
    }

    static func json(_ o: Any) -> String {
        (try? JSONSerialization.data(withJSONObject: o)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
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
        case .handedBack: js("hush.handedBack()")
        case .sequence(let name, let labels): js("hush.sequence(\(Self.json([name]))[0], \(Self.json(labels)))")
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

    func portrait(pose: String, expression: String) async -> NSImage? {
        guard ready, let svg = try? await webView.evaluateJavaScript("hush.portrait(\(Self.jsString(pose)), \(Self.jsString(expression)))") as? String
        else { return nil }
        return NSImage(data: Data(svg.utf8))
    }

    private static func jsString(_ s: String) -> String {
        (try? String(data: JSONSerialization.data(withJSONObject: [s]), encoding: .utf8)).map { String($0.dropFirst().dropLast()) } ?? "\"\""
    }

    /// README recordings: the character right now as standalone SVG, and where it is in the web view (top-left
    /// origin, points). nil while hidden or not ready.
    func snapshotSVG() async -> (svg: String, rect: CGRect, opacity: CGFloat)? {
        guard let result = try? await webView.evaluateJavaScript("hush.snapshot()") as? String,
              let data = result.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let svg = o["svg"] as? String, let x = o["x"] as? Double, let y = o["y"] as? Double,
              let w = o["w"] as? Double, let h = o["h"] as? Double else { return nil }
        return (svg, CGRect(x: x, y: y, width: w, height: h), CGFloat(o["o"] as? Double ?? 1))
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
