import AppKit
import HushCore
import SwiftUI

/// The wardrobe (docs/design-guide.md §6a): sidebar of slots with counts, a 6-column grid grouped Yours / From packs /
/// Rare, and a preview pane. Everything is free for now (packs decided at launch), so there are no prices or locks;
/// rare pieces stay silhouettes until Hush finds them. Hush on screen updates live as you pick.
enum WardrobeSection: String, CaseIterable, Identifiable {
    case body = "Body", colour = "Colour", eyes = "Eyes", topper = "Topper"
    case head = "Head", face = "Face", neck = "Neck", carry = "Carry", buddy = "Buddy"
    case packs = "Packs", rare = "Rare finds"
    var id: String { rawValue }
    var slot: WearSlot? { WearSlot(rawValue: rawValue.lowercased()) }
}

struct WardrobeView: View {
    @ObservedObject var model: SettingsModel
    @State private var section: WardrobeSection? = .head
    @State private var focus: String?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach([[WardrobeSection.body, .colour, .eyes, .topper], [.head, .face, .neck, .carry, .buddy], [.packs, .rare]], id: \.self) { group in
                        ForEach(group) { row($0) }
                        Spacer().frame(height: 10)
                    }
                }
                .padding(10)
            }
            .frame(width: 200)
            .background(.regularMaterial)
            Divider()
            ScrollView { grid.padding(16).frame(maxWidth: .infinity, alignment: .topLeading) }
                .frame(maxWidth: .infinity)
            Divider()
            preview.frame(width: 300)
        }
        .frame(minWidth: 1000, minHeight: 540)
    }

    private func row(_ s: WardrobeSection) -> some View {
        Button { section = s } label: {
            HStack {
                Text(s.rawValue).font(HushFont.body)
                Spacer()
                Text("\(count(s))").font(HushFont.footer.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(section == s ? HushColor.quietFill.opacity(2) : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func count(_ s: WardrobeSection) -> Int {
        switch s {
        case .body: CharacterLook.bodies.count
        case .colour: CharacterLook.palettes.count
        case .eyes: CharacterLook.eyeStyles.count
        case .topper: CharacterLook.toppers.count - 1
        case .packs: WearPack.allCases.count
        case .rare: model.app.rare.found.count
        default: s.slot.map { slot in Wardrobe.pieces(in: slot).filter { $0.source != .rare || model.app.rare.found.contains($0.id) }.count } ?? 0
        }
    }

    // MARK: grid

    private let columns = Array(repeating: GridItem(.flexible(minimum: 60), spacing: 10), count: 6)

    @ViewBuilder private var grid: some View {
        switch section ?? .head {
        case .body: options(CharacterLook.bodies, current: model.look.body) { v in model.setLook { $0.body = v } }
        case .colour: colours
        case .eyes: options(CharacterLook.eyeStyles, current: model.look.eyes) { v in model.setLook { $0.eyes = v } }
        case .topper: options(CharacterLook.toppers, current: model.look.topper) { v in model.setLook { $0.topper = v } }
        case .packs: packs
        case .rare: RareFindsGrid(state: model.app.rare.state, body_: model.look.body)
        case let s: if let slot = s.slot { slotGrid(slot) }
        }
    }

    private func slotGrid(_ slot: WearSlot) -> some View {
        let pieces = Wardrobe.pieces(in: slot)
        let found = model.app.rare.found
        return VStack(alignment: .leading, spacing: 16) {
            group("Yours", [nil] + pieces.filter { $0.source == .free }.map(Optional.some), slot: slot)
            let fromPacks = pieces.filter { if case .pack = $0.source { return true } else { return false } }
            if !fromPacks.isEmpty { group("From packs", fromPacks.map(Optional.some), slot: slot) }
            let rare = pieces.filter { $0.source == .rare }
            if !rare.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(rare.allSatisfy { !found.contains($0.id) } ? "Rare, not found yet" : "Rare").font(HushFont.tag).foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(rare) { p in
                            if found.contains(p.id) { tile(p, slot: slot) } else {
                                VStack(spacing: 4) {
                                    PieceTile(id: p.id, hushBody: model.look.body, silhouette: true, size: 64)
                                    HushTag(text: "Rare", tone: .lilac)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func group(_ title: String, _ pieces: [WearPiece?], slot: WearSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(HushFont.tag).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(pieces, id: \.?.id) { p in
                    if let p { tile(p, slot: slot) } else { noneTile(slot) }
                }
            }
        }
    }

    private func tile(_ p: WearPiece, slot: WearSlot) -> some View {
        let on = model.look.outfit[slot.rawValue] == p.id
        return Button {
            focus = p.id
            model.setLook { $0.outfit[slot.rawValue] = p.id }
        } label: {
            VStack(spacing: 4) {
                PieceTile(id: p.id, hushBody: model.look.body, size: 64)
                Text(p.name).font(HushFont.footer).lineLimit(1)
                if case .pack(let pack) = p.source { HushTag(text: pack.displayName, tone: .grey) }
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(on ? HushColor.lilacTint : HushColor.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? HushColor.lilacInk : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func noneTile(_ slot: WearSlot) -> some View {
        let on = model.look.outfit[slot.rawValue] == nil
        return Button { focus = nil; model.setLook { $0.outfit[slot.rawValue] = nil } } label: {
            VStack(spacing: 4) {
                Image(systemName: "circle.slash").font(.system(size: 24)).foregroundStyle(.tertiary).frame(width: 64, height: 64)
                Text("None").font(HushFont.footer)
            }
            .padding(6).frame(maxWidth: .infinity)
            .background(on ? HushColor.lilacTint : HushColor.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? HushColor.lilacInk : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func options(_ values: [String], current: String, pick: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(values, id: \.self) { v in
                Button { pick(v) } label: {
                    Text(v.capitalized).font(HushFont.body.weight(v == current ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(v == current ? HushColor.primaryText : .primary)
                        .background(v == current ? HushColor.primaryFill : HushColor.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colours: some View {
        let palettes = (try? JSONSerialization.jsonObject(with: Data(contentsOf: Assets.root.appendingPathComponent("character/palettes.json")))) as? [String: [String: String]] ?? [:]
        return VStack(alignment: .leading, spacing: 16) {
            ForEach([("Yours", Wardrobe.freeColours), ("Colours pack", Wardrobe.packColours)], id: \.0) { title, names in
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(HushFont.tag).foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(names, id: \.self) { n in
                            let hex = palettes[n]?["body"].flatMap { UInt32($0.dropFirst(), radix: 16) } ?? 0xCCCCCC
                            Button { model.setLook { $0.palette = n } } label: {
                                VStack(spacing: 4) {
                                    Circle().fill(Color(hex: hex)).frame(width: 40, height: 40)
                                        .overlay(Circle().strokeBorder(model.look.palette == n ? HushColor.lilacInk : HushColor.hairline, lineWidth: 2).padding(-4))
                                    Text(n.capitalized).font(HushFont.footer)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var packs: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(WearPack.allCases, id: \.self) { pack in
                VStack(alignment: .leading, spacing: 8) {
                    Text(pack.displayName).font(HushFont.cardTitle)
                    let pieces = Wardrobe.pieces.filter { $0.source == .pack(pack) }
                    if pack == .colours {
                        Text(Wardrobe.packColours.map(\.capitalized).joined(separator: " · ")).font(HushFont.body).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) { ForEach(pieces) { p in tile(p, slot: p.slot) } }
                    }
                }
            }
            Text("All packs are free for now.").font(HushFont.footer).foregroundStyle(.tertiary)
        }
    }

    // MARK: preview

    private var preview: some View {
        VStack(spacing: 14) {
            Spacer()
            if let id = focus ?? WearSlot.allCases.compactMap({ model.look.outfit[$0.rawValue] }).first {
                PieceTile(id: id, hushBody: model.look.body, size: 220)
                Text(Wardrobe.piece(id)?.name ?? id).font(HushFont.cardTitle)
            } else {
                Image(systemName: "tshirt").font(.system(size: 48)).foregroundStyle(.tertiary)
                Text("Pick something to try").font(HushFont.body).foregroundStyle(.secondary)
            }
            Text("Hush on your screen wears it right away.").font(HushFont.footer).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HushColor.quietFill)
    }
}

@MainActor
final class WardrobeWindowController {
    private var window: NSWindow?
    private let model: SettingsModel
    init(model: SettingsModel) { self.model = model }

    func show() {
        model.reload()
        let w = window ?? {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Wardrobe"
            w.isReleasedWhenClosed = false
            w.toolbarStyle = .unified
            w.contentView = NSHostingView(rootView: WardrobeView(model: model))
            w.center()
            return w
        }()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }
}
