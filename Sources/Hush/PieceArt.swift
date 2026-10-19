import AppKit
import HushCore
import SwiftUI

/// Preview art for a wearable: the designer's SVG of Hush wearing it (assets/character/swag), per body.
enum PieceArt {
    private static let aliases = ["propellerCap": "propeller"]
    private nonisolated(unsafe) static var cache: [String: NSImage] = [:]

    static func url(_ id: String, body: String) -> URL? {
        let root = Assets.root.appendingPathComponent("character/swag")
        let name = "\(body)-\(aliases[id] ?? id).svg"
        let fm = FileManager.default
        var dirs = WearSlot.allCases.map { root.appendingPathComponent($0.rawValue) }
        dirs += WearSlot.allCases.map { root.appendingPathComponent("rare/\($0.rawValue)") }
        dirs += WearPack.allCases.map { root.appendingPathComponent("packs/\($0.rawValue)") }
        return dirs.map { $0.appendingPathComponent(name) }.first { fm.fileExists(atPath: $0.path) }
    }

    @MainActor static func image(_ id: String, body: String) -> NSImage? {
        let key = "\(body)/\(id)"
        if let i = cache[key] { return i }
        guard let u = url(id, body: body), let i = NSImage(contentsOf: u) else { return nil }
        cache[key] = i
        return i
    }
}

/// A wearable tile: the art, or a silhouette when it isn't yours yet.
struct PieceTile: View {
    let id: String
    let hushBody: String
    var silhouette = false
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let img = PieceArt.image(id, body: hushBody) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                    .brightness(silhouette ? -1 : 0).opacity(silhouette ? 0.13 : 1)
            } else {
                Image(systemName: "questionmark").foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Character ▸ Rare finds (design guide §6b): a 4-column grid with progress. Found pieces show; unfound ones are
/// silhouettes with a vague hint once another piece of their tier has turned up.
struct RareFindsGrid: View {
    let state: RareState
    let body_: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let n = state.found.count
            HStack {
                Text("\(n) of \(RareFinds.all.count)").font(HushFont.body.weight(.semibold))
                ProgressView(value: Double(n), total: Double(RareFinds.all.count)).tint(HushColor.lilacInk)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(RareFinds.all) { f in
                    let found = state.found[f.id] != nil
                    VStack(spacing: 4) {
                        PieceTile(id: f.id, hushBody: body_, silhouette: !found, size: 58)
                        Text(found ? (Wardrobe.piece(f.id)?.name ?? f.id) : (RareFinds.showsHint(f, state: state) ? f.hint : "Not found yet"))
                            .font(HushFont.footer).foregroundStyle(found ? .primary : .tertiary)
                            .lineLimit(2).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
