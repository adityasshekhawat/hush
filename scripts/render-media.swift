// Renders the character pack into GIFs and PNGs for the README (docs/media). No dependencies: AppKit draws the SVGs,
// ImageIO writes the GIFs. Frame timings come from assets/character/animations/timing.json, so a GIF plays exactly
// like the app. Re-run after new art lands:
//
//   swift scripts/render-media.swift
//
// The character is reserved art (LICENSE-ASSETS.md); these renders are copies of it, under the same terms.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let char = root.appendingPathComponent("assets/character")
let out = root.appendingPathComponent("docs/media")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

/// 2× the 160 × 146 canvas, on paper so the GIF reads the same in GitHub's light and dark themes.
let size = NSSize(width: 320, height: 292)
let paper = NSColor(red: 1, green: 0xFD / 255.0, blue: 0xF7 / 255.0, alpha: 1)

struct Frame: Decodable { let file: String; let ms: Int }
struct Sequence: Decodable { let folder: String; let frames: [Frame] }
let sequences = try JSONDecoder().decode([Sequence].self, from: Data(contentsOf: char.appendingPathComponent("animations/timing.json")))
let palettes = try JSONSerialization.jsonObject(with: Data(contentsOf: char.appendingPathComponent("palettes.json"))) as! [String: [String: String]]

/// The pack is drawn in oat; swap its three fills for another palette, like the app's renderer does.
func recolor(_ svg: String, to palette: String) -> String {
    guard palette != "oat", let p = palettes[palette], let oat = palettes["oat"] else { return svg }
    var s = svg
    for slot in ["body", "belly", "accent"] {
        guard let from = oat[slot], let to = p[slot] else { continue }
        s = s.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
    }
    return s
}

func render(_ svgURL: URL, palette: String) -> CGImage {
    let svg = recolor(try! String(contentsOf: svgURL, encoding: .utf8), to: palette)
    guard let img = NSImage(data: Data(svg.utf8)) else { fatalError("can't read \(svgURL.lastPathComponent)") }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    paper.setFill()
    NSRect(origin: .zero, size: size).fill()
    img.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

func gif(_ folder: String, palette: String, name: String, holdLast: Int = 700) {
    guard let seq = sequences.first(where: { $0.folder.hasSuffix(folder) }) else { fatalError("no sequence \(folder)") }
    let dest = CGImageDestinationCreateWithURL(out.appendingPathComponent("\(name).gif") as CFURL,
                                               UTType.gif.identifier as CFString, seq.frames.count, nil)!
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for (i, f) in seq.frames.enumerated() {
        let ms = f.ms + (i == seq.frames.count - 1 ? holdLast : 0)
        let props = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: Double(ms) / 1000]]
        CGImageDestinationAddImage(dest, render(char.appendingPathComponent("\(seq.folder)/\(f.file)"), palette: palette),
                                   props as CFDictionary)
    }
    guard CGImageDestinationFinalize(dest) else { fatalError("couldn't write \(name).gif") }
    print("docs/media/\(name).gif · \(seq.frames.count) frames")
}

func png(_ path: String, palette: String, name: String) {
    let image = NSBitmapImageRep(cgImage: render(char.appendingPathComponent(path), palette: palette))
    try! image.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name).png"))
    print("docs/media/\(name).png")
}

// The README's set. Palettes vary so the page shows Hush can be yours.
gif("04-poke", palette: "lilac", name: "poke")
gif("05-inbox-zero", palette: "oat", name: "inbox-zero")
gif("08-morning-wake-up", palette: "mint", name: "morning")
gif("01-command-window", palette: "sky", name: "ask-hush")
gif("02-dragged-around-then-dizzy", palette: "rose", name: "dizzy")
gif("06-window-perch", palette: "lilac", name: "perch")
gif("09-focus-mode-and-screen-sharing", palette: "oat", name: "hides")
png("states/04-hold.svg", palette: "lilac", name: "holds-envelope")
png("states/05-clock.svg", palette: "mint", name: "holds-clock")
