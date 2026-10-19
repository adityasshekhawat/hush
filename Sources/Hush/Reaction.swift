import CoreGraphics

/// Live interaction cues. Purely cosmetic: none of these can make Hush interrupt (PRD § Delight).
enum Reaction {
    /// Pointer is over the character.
    case hover(Bool)
    /// Mouse button down / up on the character.
    case press(Bool)
    /// Held still for a moment: "pat" (it leans into it).
    case pat(Bool)
    /// A click that didn't open anything: hop, wave, wiggle; many in a row → dizzy, then grumpy.
    case poke
    /// Picked up and being dragged.
    case lift
    /// Horizontal drag velocity in points per second, for swinging.
    case swing(CGFloat)
    /// Hit the floor after a drop. 0…1: how hard it was flung (dizzier the harder).
    case land(intensity: CGFloat)

    // Antics (see AnticsController)
    case cheeks             // copied something: cheeks fill (or gulp and refill)
    case blow               // let the air out
    case askPat(PatAsk)
    case flash              // screenshot
    case woozy              // cursor shaken
    case flinch(dx: CGFloat)
    case perk               // charger plugged in
    case morning
    case dance
    case tuckIn
    /// Persistent moods: "groove" (music playing), "droopy" (low battery), "late" (late night);
    /// and pose modes: "walk" (edge walk loop), "perch" (sitting on a window's title bar).
    case mode(String, Bool)
    case perchDoze(Bool)
    /// Ignored-and-getting-grumpy stage (opt-in Moods): 0 none, 1 tap foot, 2 arms crossed, 3 stomp → huff.
    case mood(Int)
    case inboxZero
    case commandWindow
    /// Crouch and spring up (hopping onto a window).
    case jump
    /// Window ordered in/out (calls): pause all animation while it's gone.
    case visible(Bool)
    case debugCalm(String)
    /// Dropped onto a window's top edge: settle straight into the perch.
    case perchLand
    /// Ask Hush: waves a question off to another assistant / hands an answer over / sorry, it failed.
    case wave
    case handOver
    case sorry
    /// While the command box is open: sitListen (typing), sitThink (repo route), sitPoint (hand-off); nil when it closes.
    case boxPose(String?)
    /// The weekly held-back card: a moment of pride.
    case proud
    /// The first time Hush finds a rare piece (design guide §6b).
    case rareFirst(String)

    enum PatAsk: String { case start, thanked, ignored }
}

enum RendererEvent {
    case ready
    /// The character's drawn bounds, in the view's top-left-origin coordinates.
    case bounds(CGRect)
}
