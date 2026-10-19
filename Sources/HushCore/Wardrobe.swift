import Foundation

/// What Hush can wear (docs/design-guide.md §6, 6a, 6b). Everything Hush *does* is free; pieces only change how it
/// looks. Each piece maps to rig layer ids (assets/character/rig): the renderer copies those layers into the pose.
public enum WearSlot: String, Sendable, CaseIterable, Codable {
    case head, face, neck, carry, buddy

    public var displayName: String {
        switch self {
        case .head: "Head"
        case .face: "Face"
        case .neck: "Neck"
        case .carry: "Carry"
        case .buddy: "Buddy"
        }
    }
}

public enum WearPack: String, Sendable, CaseIterable {
    case builder, cozy, studio, dressup, colours

    public var displayName: String {
        switch self {
        case .builder: "Builder"
        case .cozy: "Cozy"
        case .studio: "Studio"
        case .dressup: "Dress-up"
        case .colours: "Colours"
        }
    }
}

public struct WearPiece: Sendable, Equatable, Identifiable {
    public enum Source: Sendable, Equatable {
        case free
        case pack(WearPack)
        /// Found by Hush on its own (rare finds); never sold.
        case rare
    }

    public var id: String
    public var name: String
    public var slot: WearSlot
    public var source: Source
    /// Rig layer ids, in drawing order (the cape has a back layer behind the body and a front clasp).
    public var layers: [String]
}

public enum Wardrobe {
    public static let pieces: [WearPiece] = [
        // Free classics
        .init(id: "cap", name: "Cap", slot: .head, source: .free, layers: ["accessory-cap"]),
        .init(id: "capBack", name: "Backwards cap", slot: .head, source: .free, layers: ["head-cap-back"]),
        .init(id: "beanie", name: "Beanie", slot: .head, source: .free, layers: ["head-beanie"]),
        .init(id: "bucket", name: "Bucket hat", slot: .head, source: .free, layers: ["head-bucket"]),
        .init(id: "headphones", name: "Headphones", slot: .head, source: .free, layers: ["head-headphones"]),
        .init(id: "crown", name: "Crown", slot: .head, source: .free, layers: ["head-crown"]),
        .init(id: "sweatband", name: "Sweatband", slot: .head, source: .free, layers: ["head-sweatband"]),
        .init(id: "glasses", name: "Glasses", slot: .face, source: .free, layers: ["accessory-glasses"]),
        .init(id: "shades", name: "Shades", slot: .face, source: .free, layers: ["face-shades"]),
        .init(id: "scarf", name: "Scarf", slot: .neck, source: .free, layers: ["accessory-scarf"]),
        .init(id: "bandana", name: "Bandana", slot: .neck, source: .free, layers: ["neck-bandana"]),
        .init(id: "bowtie", name: "Bow tie", slot: .neck, source: .free, layers: ["neck-bowtie"]),
        .init(id: "chain", name: "Chain", slot: .neck, source: .free, layers: ["neck-chain"]),
        .init(id: "satchel", name: "Satchel", slot: .carry, source: .free, layers: ["carry-satchel"]),
        // Builder
        .init(id: "hardHat", name: "Hard hat", slot: .head, source: .pack(.builder), layers: ["pack-head-hard-hat"]),
        .init(id: "pixelShades", name: "Pixel shades", slot: .face, source: .pack(.builder), layers: ["pack-face-pixel-shades"]),
        .init(id: "lanyard", name: "Lanyard", slot: .neck, source: .pack(.builder), layers: ["pack-neck-lanyard"]),
        .init(id: "laptop", name: "Laptop", slot: .carry, source: .pack(.builder), layers: ["pack-carry-laptop"]),
        // Cozy
        .init(id: "frogHat", name: "Frog hat", slot: .head, source: .pack(.cozy), layers: ["pack-head-frog"]),
        .init(id: "bunny", name: "Bunny ears", slot: .head, source: .pack(.cozy), layers: ["pack-head-bunny"]),
        .init(id: "coffee", name: "Coffee", slot: .carry, source: .pack(.cozy), layers: ["pack-carry-coffee"]),
        .init(id: "books", name: "Books", slot: .carry, source: .pack(.cozy), layers: ["pack-carry-books"]),
        // Studio
        .init(id: "beret", name: "Beret", slot: .head, source: .pack(.studio), layers: ["pack-head-beret"]),
        .init(id: "flowerClip", name: "Flower clip", slot: .head, source: .pack(.studio), layers: ["pack-head-flower-clip"]),
        .init(id: "starGlasses", name: "Star glasses", slot: .face, source: .pack(.studio), layers: ["pack-face-star-glasses"]),
        .init(id: "plant", name: "Plant", slot: .carry, source: .pack(.studio), layers: ["pack-carry-plant"]),
        // Dress-up
        .init(id: "wizard", name: "Wizard hat", slot: .head, source: .pack(.dressup), layers: ["pack-head-wizard"]),
        .init(id: "chef", name: "Chef's hat", slot: .head, source: .pack(.dressup), layers: ["pack-head-chef"]),
        .init(id: "straw", name: "Straw hat", slot: .head, source: .pack(.dressup), layers: ["pack-head-straw"]),
        .init(id: "tie", name: "Tie", slot: .neck, source: .pack(.dressup), layers: ["pack-neck-tie"]),
        .init(id: "cape", name: "Cape", slot: .neck, source: .pack(.dressup), layers: ["pack-cape-back", "pack-neck-cape-clasp"]),
        // Rare finds
        .init(id: "bird", name: "Bird", slot: .buddy, source: .rare, layers: ["buddy-bird"]),
        .init(id: "snail", name: "Snail", slot: .buddy, source: .rare, layers: ["buddy-snail"]),
        .init(id: "butterfly", name: "Butterfly", slot: .buddy, source: .rare, layers: ["buddy-butterfly"]),
        .init(id: "propellerCap", name: "Propeller cap", slot: .head, source: .rare, layers: ["rare-propeller-cap"]),
        .init(id: "cocoa", name: "Cocoa", slot: .carry, source: .rare, layers: ["rare-carry-cocoa"]),
        .init(id: "lantern", name: "Lantern", slot: .carry, source: .rare, layers: ["rare-carry-lantern"]),
        .init(id: "partyHat", name: "Party hat", slot: .head, source: .rare, layers: ["rare-party-hat"]),
        .init(id: "balloon", name: "Balloon", slot: .carry, source: .rare, layers: ["rare-carry-balloon"]),
        .init(id: "flowerCrown", name: "Flower crown", slot: .head, source: .rare, layers: ["rare-flower-crown"]),
        .init(id: "heartGlasses", name: "Heart glasses", slot: .face, source: .rare, layers: ["rare-heart-glasses"]),
        .init(id: "bell", name: "Jingle bell", slot: .neck, source: .rare, layers: ["rare-neck-bell"]),
        .init(id: "halo", name: "Halo", slot: .head, source: .rare, layers: ["rare-halo"]),
        .init(id: "lei", name: "Welcome lei", slot: .neck, source: .rare, layers: ["rare-neck-lei"]),
        .init(id: "monocle", name: "Monocle", slot: .face, source: .rare, layers: ["rare-monocle"]),
    ]

    /// Free colours, then the Colours pack.
    public static let freeColours = ["oat", "mint", "lilac", "sky", "rose"]
    public static let packColours = ["peach", "matcha", "butter", "berry"]

    public static func piece(_ id: String) -> WearPiece? { pieces.first { $0.id == id } }
    public static func pieces(in slot: WearSlot) -> [WearPiece] { pieces.filter { $0.slot == slot } }
    public static var free: [WearPiece] { pieces.filter { $0.source == .free } }

    /// Rig layers to draw for an outfit (slot → piece id), cape back first.
    public static func layers(for outfit: [WearSlot: String]) -> [String] {
        WearSlot.allCases.compactMap { outfit[$0].flatMap(piece) }.flatMap(\.layers)
    }
}
