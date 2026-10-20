import AppKit
import AVFoundation
import HushMac
import ImageIO
import UniformTypeIdentifiers
import WebKit

/// Developer tool (debug hooks only): records Hush's own windows into a GIF for the README, or an MP4 for the website,
/// with no screen-recording permission. Each frame snapshots the character through WebKit and every card or bubble
/// through AppKit, then composites them over a drawn desktop, so the media show exactly what the app draws and never
/// anything else on the screen (no real windows, tabs or desktop).
///   record:start:<name>   …play a scenario…   record:stop        → recordings/<name>.gif (500 × 430 pt, 8 fps)
///   video:start:<name>    …                   video:stop         → recordings/<name>.mp4 (768 × 432 pt, 720p, 30 fps)
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

    // Video
    private var video: VideoWriter?
    private var startedAt = Date()
    /// A title over the video ("Hush watches your agents"), set by the scenario; fades in when it changes.
    var caption: String? { didSet { if caption != oldValue { captionAt = Date() } } }
    private var captionAt = Date.distantPast

    var isRecording: Bool { timer != nil }
    /// The character as standalone SVG and its web view (WebKit's own snapshot misses running animations).
    var characterSVG: (() async -> (svg: String, rect: CGRect, opacity: CGFloat)?)?

    /// `around`: Hush's panel; the recording is a 500 × 430 pt window of the screen above and around it.
    func start(name: String, around hush: NSRect, screen: NSRect) {
        begin(name: name, size: NSSize(width: 500, height: 430), around: hush, screen: screen, fps: Self.fps)
    }

    /// A 16:9 video of the bottom of the screen around Hush, written to disk as it goes.
    func startVideo(name: String, around hush: NSRect, screen: NSRect) {
        begin(name: name, size: NSSize(width: 768, height: 432), around: hush, screen: screen, fps: VideoWriter.fps)
        do {
            video = try VideoWriter(url: Self.folder.appendingPathComponent("\(name).mp4"),
                                    width: VideoWriter.width, height: VideoWriter.height)
        } catch {
            DiagnosticsLog.write("record: couldn't start the video (\(error.localizedDescription))")
            stop()
        }
    }

    private func begin(name: String, size: NSSize, around hush: NSRect, screen: NSRect, fps: Double) {
        stopTimer()
        self.name = name
        frames = []
        caption = nil
        startedAt = Date()
        let x = min(max(hush.midX - size.width / 2, screen.minX), screen.maxX - size.width)
        rect = NSRect(x: x, y: screen.minY, width: size.width, height: size.height)
        appearanceBefore = NSApp.appearance
        NSApp.appearance = NSAppearance(named: .aqua)
        SurfaceStyle.recording = true
        timer = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture() }
        }
        DiagnosticsLog.write("record: started \(name)")
    }

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Hush/recordings")
    }

    func stop() {
        stopTimer()
        NSApp.appearance = appearanceBefore
        SurfaceStyle.recording = false
        caption = nil
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        if let v = video {
            video = nil
            let name = self.name
            v.finish { ok, count in
                DiagnosticsLog.write("record: \(ok ? "wrote" : "couldn't write") \(name).mp4 (\(count) frames)")
            }
            return
        }
        let out = Self.folder.appendingPathComponent("\(name).gif")
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
        let at = Date().timeIntervalSince(startedAt)
        // Back to front. (`orderedWindows` leaves out panels, and every Hush window is one; orderedIndex 0 is frontmost.)
        // Not filtered on alphaValue: a bubble faded in through the animator still reads 0 while fully on screen.
        // The stage window (a perch for the video) is drawn as a generic window, never its contents.
        let visible = NSApp.windows.filter { $0.isVisible && $0.frame.intersects(rect) }
        let stages = visible.filter { $0 is StageWindow }.map(\.frame)
        let windows = visible.filter { !($0 is StageWindow) }.sorted { $0.orderedIndex > $1.orderedIndex }
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
            if let v = self.video {
                if let frame = self.composite(layers, width: VideoWriter.width, stages: stages, video: true) { v.append(frame, at: at) }
            } else if let frame = self.composite(layers, width: Self.outWidth, stages: stages, video: false) {
                self.frames.append(frame)
            }
            self.busy = false
        }
    }

    private func composite(_ layers: [(NSImage, NSRect, CGFloat)], width: Int, stages: [NSRect], video: Bool) -> CGImage? {
        let scale: CGFloat = CGFloat(width) / rect.width
        let px = NSSize(width: rect.width * scale, height: rect.height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let origin = rect.origin
        let local = { (f: NSRect) in NSRect(x: (f.minX - origin.x) * scale, y: (f.minY - origin.y) * scale,
                                            width: f.width * scale, height: f.height * scale) }
        let canvas = NSRect(origin: .zero, size: px)
        Self.wallpaper(canvas)
        // One plain window behind Hush for scale; the video keeps it to the side so the middle stays Hush's.
        Self.drawWindow(video ? NSRect(x: px.width * 0.66, y: px.height * 0.5, width: px.width * 0.3, height: px.height * 0.42)
                              : NSRect(x: px.width * 0.06, y: px.height * 0.42, width: px.width * 0.5, height: px.height * 0.5),
                        scale: scale)
        for s in stages { Self.drawWindow(local(s), scale: scale) }
        for (img, frame, alpha) in layers {
            img.draw(in: local(frame), from: .zero, operation: .sourceOver, fraction: alpha)
        }
        if video { drawCaption(in: canvas, scale: scale) }
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    /// A calm desktop: a soft lilac-to-oat wallpaper.
    private static func wallpaper(_ r: NSRect) {
        NSGradient(colors: [NSColor(red: 0.86, green: 0.82, blue: 0.96, alpha: 1), NSColor(red: 0.98, green: 0.92, blue: 0.84, alpha: 1)])!
            .draw(in: r, angle: -60)
    }

    /// A plain app window: no title, no content, just shapes, so nothing real is ever shown.
    private static func drawWindow(_ win: NSRect, scale: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.10)
        shadow.shadowBlurRadius = 16 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -5 * scale)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(white: 1, alpha: 0.9).setFill()
        NSBezierPath(roundedRect: win, xRadius: 10 * scale, yRadius: 10 * scale).fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor(white: 0, alpha: 0.06).setFill()
        let lines = Int((win.height / scale - 60) / 22)
        for i in 0..<max(0, min(lines, 8)) {
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

    /// The scene's title, top left, fading in over 0.4 s. A second line is the quieter subtitle.
    private func drawCaption(in r: NSRect, scale: CGFloat) {
        guard let caption, !caption.isEmpty else { return }
        let t = CGFloat(min(1, Date().timeIntervalSince(captionAt) / 0.4))
        let ink = NSColor(red: 0x2D / 255, green: 0x2A / 255, blue: 0x35 / 255, alpha: 1)
        var y = r.maxY - 70 * scale
        for (i, line) in caption.components(separatedBy: "\n").enumerated() {
            let font = i == 0 ? NSFont.systemFont(ofSize: 30 * scale, weight: .bold) : NSFont.systemFont(ofSize: 17 * scale, weight: .medium)
            let s = NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: ink.withAlphaComponent(t * (i == 0 ? 1 : 0.65))])
            s.draw(at: NSPoint(x: 44 * scale, y: y - (1 - t) * 8 * scale))
            y -= (i == 0 ? 30 : 24) * scale
        }
    }

    private static func webView(in v: NSView) -> WKWebView? {
        if let w = v as? WKWebView { return w }
        for s in v.subviews { if let w = webView(in: s) { return w } }
        return nil
    }
}

/// A blank window Hush opens for the video so it has something of its own to perch on. The recorder draws it as a
/// generic window; on screen it's empty. Debug hooks only.
final class StageWindow: NSWindow {}

/// H.264 MP4 written frame by frame (the README GIFs keep frames in memory; a 90 s video can't).
final class VideoWriter {
    static let width = 1280, height = 720
    static let fps: Double = 30
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var last: Double = -1
    private var count = 0

    init(url: URL, width: Int, height: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 1_800_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 60,
            ],
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ image: CGImage, at seconds: Double) {
        guard seconds > last + 0.001, input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer),
                               height: CVPixelBufferGetHeight(buffer), bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        if adaptor.append(buffer, withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 600)) {
            last = seconds
            count += 1
        }
    }

    func finish(_ done: @escaping @MainActor (Bool, Int) -> Void) {
        input.markAsFinished()
        let n = count
        // The writer is done with by the time this runs; the closure only reads its status.
        nonisolated(unsafe) let w = writer
        w.finishWriting {
            let ok = w.status == .completed
            DispatchQueue.main.async { MainActor.assumeIsolated { done(ok, n) } }
        }
    }
}
