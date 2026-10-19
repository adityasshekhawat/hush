import Foundation
import HushCore

/// Locates bundled assets: inside Hush.app/Contents/Resources when bundled, else the repo's assets/ folder
/// (so `swift run Hush` works during development).
enum Assets {
    static var root: URL {
        if let r = Bundle.main.resourceURL?.appendingPathComponent("assets"),
           FileManager.default.fileExists(atPath: r.appendingPathComponent("renderer/index.html").path) {
            return r
        }
        // Sources/Hush/CharacterRenderer.swift → repo root
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("assets")
    }

    /// The renderer page: index.html with style.css and the JS fragments inlined (they share one closure).
    static func rendererPage() throws -> String {
        let dir = root.appendingPathComponent("renderer")
        var html = try String(contentsOf: dir.appendingPathComponent("index.html"), encoding: .utf8)
        for part in ["style.css", "setup.js", "compose.js", "life.js", "reactions.js"] {
            let text = try String(contentsOf: dir.appendingPathComponent(part), encoding: .utf8)
            html = html.replacingOccurrences(of: "/*@inline \(part)*/", with: text)
        }
        return html
    }

    /// The JSON blob the renderer page expects as window.HUSH_DATA.

    /// Every pose and expression per body, the rig per body × eye style (toppers, accessories, eye shapes, mouths,
    /// fx), the designer's sequences (timing.json), and the command-window keyframes (their box isn't in any pose).
    /// Poses and expressions are separate maps: `dizzy` and `yawn` are both.
    static func rendererData() throws -> String {
        let character = root.appendingPathComponent("character")
        let fm = FileManager.default
        func svgs(in dir: URL) throws -> [String: String] {
            var out: [String: String] = [:]
            for f in try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) where f.pathExtension == "svg" {
                out[f.deletingPathExtension().lastPathComponent] = try String(contentsOf: f, encoding: .utf8)
            }
            return out
        }
        var poses: [String: [String: String]] = [:], expressions: [String: [String: String]] = [:], rigs: [String: [String: String]] = [:]
        for body in CharacterLook.bodies {
            poses[body] = try svgs(in: character.appendingPathComponent("poses/\(body)"))
            expressions[body] = try svgs(in: character.appendingPathComponent("expressions/\(body)"))
            var r: [String: String] = [:]
            for style in CharacterLook.eyeStyles {
                r[style] = try String(contentsOf: character.appendingPathComponent("rig/hush-rig-\(body)-\(style).svg"), encoding: .utf8)
            }
            rigs[body] = r
        }
        let animations = character.appendingPathComponent("animations")
        let payload: [String: Any] = [
            "poses": poses,
            "expressions": expressions,
            "rigs": rigs,
            "commandFrames": try svgs(in: animations.appendingPathComponent("01-command-window")),
            "timing": try JSONSerialization.jsonObject(with: Data(contentsOf: animations.appendingPathComponent("timing.json"))),
            "palettes": try JSONSerialization.jsonObject(with: Data(contentsOf: character.appendingPathComponent("palettes.json"))),
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
    }

}
