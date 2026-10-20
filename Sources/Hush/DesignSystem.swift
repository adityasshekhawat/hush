import AppKit
import SwiftUI

/// Hush's design tokens and shared pieces (docs/design-guide.md §2). Native first: system fonts, SF Symbols,
/// materials and system colours for status. Warmth comes from the character and the copy, not decoration.

// MARK: - Colour

extension Color {
    /// A colour that follows light/dark mode.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .vibrantDark]) != nil ? dark : light })
    }

    init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

enum HushColor {
    static let ink = Color(hex: 0x2D2A35)
    static let paper = Color(hex: 0xFFFDF7)
    static let oat = Color(hex: 0xF4D9A6)
    static let coral = Color(hex: 0xE8876A)
    static let lilac = Color(hex: 0xC9BBEC)
    /// Quick-lane chip text and the held-back number.
    static let lilacInk = Color(light: NSColor(hex: 0x5B47A8), dark: NSColor(hex: 0xC9BBEC))
    static let lilacTint = Color(light: NSColor(hex: 0xF1ECFB), dark: NSColor(hex: 0xC9BBEC, alpha: 0.22))

    // Status: always system colours, always paired with a word or symbol.
    static let working = Color(nsColor: .systemBlue)
    static let done = Color(nsColor: .systemGreen)
    static let needsYou = Color(nsColor: .systemOrange)
    static let failed = Color(nsColor: .systemRed)

    /// Secondary pills and inner blocks: label colour at 6 %.
    static let quietFill = Color(nsColor: .labelColor).opacity(0.06)
    /// The primary pill: ink in light mode, paper in dark.
    static let primaryFill = Color(light: NSColor(hex: 0x2D2A35), dark: NSColor(hex: 0xFFFDF7))
    static let primaryText = Color(light: .white, dark: NSColor(hex: 0x2D2A35))
    static let hairline = Color(nsColor: .labelColor).opacity(0.1)
}

/// Tag and chip tints (light: fixed pairs; dark: the system colour at 22 % with the colour itself as text).
enum Tone: Sendable {
    case blue, green, orange, red, grey, lilac, coral

    var fill: Color {
        switch self {
        case .blue: Color(light: NSColor(hex: 0xE1ECFD), dark: NSColor.systemBlue.withAlphaComponent(0.22))
        case .green: Color(light: NSColor(hex: 0xDDF3E4), dark: NSColor.systemGreen.withAlphaComponent(0.22))
        case .orange: Color(light: NSColor(hex: 0xFFEBD1), dark: NSColor.systemOrange.withAlphaComponent(0.22))
        case .red: Color(light: NSColor(hex: 0xFDE1DE), dark: NSColor.systemRed.withAlphaComponent(0.22))
        case .grey: Color(light: NSColor.black.withAlphaComponent(0.06), dark: NSColor.white.withAlphaComponent(0.1))
        case .lilac: HushColor.lilacTint
        case .coral: Color(light: NSColor(hex: 0xFBE1D8), dark: NSColor(hex: 0xE8876A, alpha: 0.22))
        }
    }

    var text: Color {
        switch self {
        case .blue: Color(light: NSColor(hex: 0x1F5FBF), dark: .systemBlue)
        case .green: Color(light: NSColor(hex: 0x1E7A3C), dark: .systemGreen)
        case .orange: Color(light: NSColor(hex: 0xA35A00), dark: .systemOrange)
        case .red: Color(light: NSColor(hex: 0xB4261A), dark: .systemRed)
        case .grey: Color(light: NSColor(hex: 0x4F4858), dark: .secondaryLabelColor)
        case .lilac: HushColor.lilacInk
        case .coral: Color(light: NSColor(hex: 0x9A3E22), dark: NSColor(hex: 0xE8876A))
        }
    }
}

// MARK: - Type (system fonts only)

enum HushFont {
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    static let onboardingTitle = Font.system(size: 20, weight: .bold)
    static let body = Font.system(size: 13)
    static let answerBody = Font.system(size: 13.5)
    static let subtitle = Font.system(size: 12.5)
    static let footer = Font.system(size: 11.5)
    static let tag = Font.system(size: 11, weight: .semibold)
    static let mono = Font.system(size: 12.5, design: .monospaced)
    /// Hush's numbers: the held-back count (26 to 34) and fact answers (40).
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

enum HushSpace {
    static let cardH: CGFloat = 16
    static let cardV: CGFloat = 14
    static let cardRadius: CGFloat = 16
    static let innerRadius: CGFloat = 11
}

// MARK: - Buttons

/// Custom pills: macOS prominent buttons render grey in non-activating panels.
struct HushPill: ButtonStyle {
    enum Kind { case primary, secondary, quiet, consent, smallStop }
    var kind: Kind = .secondary
    /// Shown inside the pill at 60 %, e.g. "⌘⏎".
    var shortcut: String?
    var height: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, kind: kind, shortcut: shortcut, height: kind == .smallStop ? 22 : height)
    }

    private struct PillBody: View {
        let configuration: Configuration
        let kind: Kind
        let shortcut: String?
        let height: CGFloat
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 6) {
                configuration.label
                if let s = shortcut { Text(s).opacity(0.6) }
            }
            .font(.system(size: kind == .smallStop ? 12 : 12.5, weight: kind == .secondary || kind == .quiet ? .medium : .semibold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .fixedSize()
            .padding(.horizontal, kind == .quiet ? 4 : (kind == .smallStop ? 9 : 12))
            .frame(height: height)
            .background(Capsule().fill(fill))
            .overlay(Capsule().fill(Color.black.opacity(hovering && kind != .quiet ? 0.08 : 0)))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering = $0 }
        }

        private var fill: Color {
            switch kind {
            case .primary: HushColor.primaryFill
            case .secondary, .smallStop: HushColor.quietFill
            case .quiet: .clear
            case .consent: HushColor.needsYou
            }
        }

        private var foreground: Color {
            switch kind {
            case .primary: HushColor.primaryText
            case .secondary, .smallStop: .primary
            case .quiet: .secondary
            case .consent: HushColor.ink
            }
        }
    }
}

extension ButtonStyle where Self == HushPill {
    static func pill(_ kind: HushPill.Kind = .secondary, shortcut: String? = nil) -> HushPill { HushPill(kind: kind, shortcut: shortcut) }
}

// MARK: - Tags, chips, tiles

/// A small tag: radius 6, 11 semibold.
struct HushTag: View {
    let text: String
    var tone: Tone = .grey
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let s = symbol { Image(systemName: s).font(.system(size: 9, weight: .bold)) }
            Text(text).font(HushFont.tag)
        }
        .foregroundStyle(tone.text)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tone.fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Envelope header icon: an 18 pt tile, radius 5, tag tint with the symbol in the tag text colour.
struct IconTile: View {
    let symbol: String
    let tone: Tone
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(tone.text)
            .frame(width: size, height: size)
            .background(tone.fill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A coloured status dot with its word ("Working", "Done"): colour never carries status alone.
struct StatusDot: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(HushFont.footer).foregroundStyle(.secondary)
        }
    }
}

/// An inner block (code, question box, sites note): radius 10 to 12.
struct InnerBlock<Content: View>: View {
    var fill: Color = HushColor.quietFill
    var stroke: Color? = nil
    var padding: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: HushSpace.innerRadius, style: .continuous))
            .overlay {
                if let stroke { RoundedRectangle(cornerRadius: HushSpace.innerRadius, style: .continuous).strokeBorder(stroke, lineWidth: 1) }
            }
    }
}

// MARK: - Motion

enum HushMotion {
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static var cardIn: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.35, bounce: 0.12) }
    static var cardOut: Animation { reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.2) }
    static var resize: Animation? { reduceMotion ? nil : .smooth(duration: 0.3) }
}

// MARK: surfaces

/// Card chrome (design guide §2, "Material"). macOS 15: material, a 0.5 pt hairline and the guide's shadow
/// (0 12 32 at 18 %). macOS 26 and later: Liquid Glass, which draws its own edge highlight and shadow, so both go
/// (v1 art notes). Status never tints the glass; only the command box takes a faint lilac to mark it as Hush's.
struct HushSurface: ViewModifier {
    var radius: CGFloat
    var interactive = false
    var tint: Color?
    var shadow = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26, *) {
            content.glassEffect(Self.glass(tint: tint, interactive: interactive), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(HushColor.hairline, lineWidth: 0.5))
                .shadow(color: .black.opacity(shadow ? 0.18 : 0), radius: 16, x: 0, y: 12)
        }
    }

    @available(macOS 26, *)
    static func glass(tint: Color?, interactive: Bool) -> Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        return interactive ? g.interactive() : g
    }
}

extension View {
    func hushSurface(radius: CGFloat, interactive: Bool = false, tint: Color? = nil, shadow: Bool = true) -> some View {
        modifier(HushSurface(radius: radius, interactive: interactive, tint: tint, shadow: shadow))
    }
}
