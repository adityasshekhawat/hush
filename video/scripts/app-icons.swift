// Exports the icons of apps installed on this Mac to public/logos/<name>.png (512 px) for the videos.
// They're other companies' trademarks: kept out of git (.gitignore), never redrawn, shown only as the apps Hush works with.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let apps: [(String, [String])] = [
    ("terminal", ["/System/Applications/Utilities/Terminal.app"]),
    ("claude", ["/Applications/Claude.app"]),
    ("calendar", ["/System/Applications/Calendar.app"]),
    ("zoom", ["/Applications/zoom.us.app"]),
    ("mail", ["/System/Applications/Mail.app"]),
    ("notes", ["/System/Applications/Notes.app"]),
    ("excel", ["/Applications/Microsoft Excel.app"]),
    ("music", ["/System/Applications/Music.app"]),
    ("safari", ["/Applications/Safari.app", "/System/Applications/Safari.app"]),
    ("facetime", ["/System/Applications/FaceTime.app"]),
    ("cursor", ["/Applications/Cursor.app"]),
    ("slack", ["/Applications/Slack.app"]),
]
var made: [String] = []
for (name, paths) in apps {
    guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { continue }
    let icon = NSWorkspace.shared.icon(forFile: path)
    let size = NSSize(width: 512, height: 512)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name).png"))
    made.append(name)
}
print("app icons: " + made.joined(separator: ", "))
