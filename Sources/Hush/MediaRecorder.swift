import AppKit
import HushMac
import ImageIO
import UniformTypeIdentifiers
import WebKit

/// Developer tool (debug hooks only): records Hush's own windows into a GIF for the README, with no screen-recording
/// permission. Each frame snapshots the character through WebKit and every card or bubble through AppKit, then
/// composites them over a plain desktop backdrop, so the GIFs show exactly what the app draws.
///   record:start:<name>   …play a scenario…   record:stop
@MainActor
final class MediaRecorder {
    private var timer: Timer?
    private var frames: [CGImage] = []
    private var name = ""
    private var rect: NSRect = .zero
    private var busy = false
    private var lastSignature = ""
    /// Recordings use the light look (the design guide's primary one) whatever the Mac is set to; restored after.
    private var appearanceBefore: NSAppearance?
    static let fps: Double = 8
    static let outWidth = 640

    var isRecording: Bool { timer != nil }
    /// The character as standalone SVG and its web view (WebKit's own snapshot misses running animations).
    var characterSVG: (() async -> (svg: String, rect: CGRect, opacity: CGFloat)?)?

    /// `around`: Hush's panel; the recording is a 500 × 430 pt window of the screen above and around it.
    func start(name: String, around hush: NSRect, screen: NSRect) {
        stopTimer()
        self.name = name
        frames = []
        let w: CGFloat = 500, h: CGFloat = 430
        let x = min(max(hush.midX - w / 2, screen.minX), screen.maxX - w)
        rect = NSRect(x: x, y: screen.minY, width: w, height: h)
        appearanceBefore = NSApp.appearance
        NSApp.appearance = NSAppearance(named: .aqua)
        timer = Timer.scheduledTimer(withTimeInterval: 1 / Self.fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture() }
        }
        DiagnosticsLog.write("record: started \(name)")
    }

    func stop() {
        stopTimer()
        NSApp.appearance = appearanceBefore
        let out = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Hush/recordings/\(name).gif")
        try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard !frames.isEmpty, let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            DiagnosticsLog.write("record: nothing to write for \(name)")
            return
        }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let props = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: 1 / Self.fps]] as CFDictionary
        for f in frames { CGImageDestinationAddImage(dest, f, props) }
        let ok = CGImageDestinationFinalize(dest)
        DiagnosticsLog.write("record: \(ok ? "wrote" : "couldn't write") \(out.path) (\(frames.count) frames)")
        frames = []
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func capture() {
        guard !busy else { return }   // a slow WebKit snapshot: skip this tick rather than pile up
        busy = true
        // Back to front. (`orderedWindows` leaves out panels, and every Hush window is one; orderedIndex 0 is frontmost.)
        // Not filtered on alphaValue: a bubble faded in through the animator still reads 0 while fully on screen.
        let windows = NSApp.windows.filter { $0.isVisible && $0.frame.intersects(rect) }
            .sorted { $0.orderedIndex > $1.orderedIndex }
        let all = NSApp.windows.filter { $0.isVisible }
        let sig = all.map { "\(type(of: $0))@\(Int($0.frame.minX)),\(Int($0.frame.minY)) a\(String(format: "%.1f", $0.alphaValue))" }.joined(separator: " ")
        if sig != lastSignature {
            lastSignature = sig
            DiagnosticsLog.write("record: \(windows.count) in view of \(all.count) visible · rect \(rect.integral) · \(sig)")
        }
        Task { @MainActor in
            var layers: [(NSImage, NSRect, CGFloat)] = []
            for w in windows {
                guard let content = w.contentView else { continue }
                if let web = Self.webView(in: content) {
                    guard let snap = await self.characterSVG?(), let img = NSImage(data: Data(snap.svg.utf8)) else { continue }
                    // Web view rect in screen coordinates, then the svg inside it (CSS is top-left origin).
                    let wv = web.convert(web.bounds, to: nil).offsetBy(dx: w.frame.minX, dy: w.frame.minY)
                    let r = NSRect(x: wv.minX + snap.rect.minX, y: wv.maxY - snap.rect.maxY, width: snap.rect.width, height: snap.rect.height)
                    layers.append((img, r, snap.opacity))
                } else if let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                    content.cacheDisplay(in: content.bounds, to: rep)
                    let img = NSImage(size: content.bounds.size)
                    img.addRepresentation(rep)
                    layers.append((img, w.frame, 1))
                }
            }
            if let frame = self.composite(layers) { self.frames.append(frame) }
            self.busy = false
        }
    }

    private func composite(_ layers: [(NSImage, NSRect, CGFloat)]) -> CGImage? {
        let scale: CGFloat = CGFloat(Self.outWidth) / rect.width
        let px = NSSize(width: rect.width * scale, height: rect.height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        Self.drawDesktop(in: NSRect(origin: .zero, size: px), scale: scale)
        for (img, frame, alpha) in layers {
            let r = NSRect(x: (frame.minX - rect.minX) * scale, y: (frame.minY - rect.minY) * scale,
                           width: frame.width * scale, height: frame.height * scale)
            img.draw(in: r, from: .zero, operation: .sourceOver, fraction: alpha)
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    /// A calm desktop: a soft lilac-to-oat wallpaper and one plain app window behind Hush, for scale.
    private static func drawDesktop(in r: NSRect, scale: CGFloat) {
        NSGradient(colors: [NSColor(red: 0.86, green: 0.82, blue: 0.96, alpha: 1), NSColor(red: 0.98, green: 0.92, blue: 0.84, alpha: 1)])!
            .draw(in: r, angle: -60)
        let win = NSRect(x: r.width * 0.06, y: r.height * 0.42, width: r.width * 0.5, height: r.height * 0.5)
        NSColor(white: 1, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: win, xRadius: 10 * scale, yRadius: 10 * scale).fill()
        NSColor(white: 0, alpha: 0.06).setFill()
        for i in 0..<5 {
            NSBezierPath(roundedRect: NSRect(x: win.minX + 22 * scale, y: win.maxY - CGFloat(48 + i * 22) * scale,
                                             width: win.width * (i % 2 == 0 ? 0.7 : 0.5), height: 8 * scale),
                         xRadius: 4 * scale, yRadius: 4 * scale).fill()
        }
        for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            c.withAlphaComponent(0.8).setFill()
            NSBezierPath(ovalIn: NSRect(x: win.minX + CGFloat(12 + i * 14) * scale, y: win.maxY - 18 * scale,
                                        width: 8 * scale, height: 8 * scale)).fill()
        }
    }

    private static func webView(in v: NSView) -> WKWebView? {
        if let w = v as? WKWebView { return w }
        for s in v.subviews { if let w = webView(in: s) { return w } }
        return nil
    }
}
