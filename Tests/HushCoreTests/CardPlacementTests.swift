import CoreGraphics
import Testing
@testable import HushCore

@Suite struct Placement {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1055)

    func hush(x: CGFloat, y: CGFloat = 0, w: CGFloat = 90, h: CGFloat = 130) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

    @Test func neverOverlapsHushAnywhereOnScreen() {
        let sizes = [CGSize(width: 400, height: 140), CGSize(width: 420, height: 480), CGSize(width: 540, height: 74), CGSize(width: 260, height: 48)]
        for x in stride(from: CGFloat(0), through: 1830, by: 61) {
            for y in [CGFloat(0), 300, 700, 900] {
                let h = hush(x: x, y: y)
                for s in sizes {
                    let f = CardPlacement.frame(size: s, avoiding: h, in: screen)
                    #expect(!f.intersects(h.insetBy(dx: -4, dy: -4)), "card \(f) covers Hush \(h)")
                    #expect(screen.insetBy(dx: -0.5, dy: -0.5).contains(f), "card \(f) off screen")
                }
            }
        }
    }

    @Test func prefersAboveWithHeadroom() {
        let h = hush(x: 1750)
        let f = CardPlacement.frame(size: CGSize(width: 400, height: 140), avoiding: h, in: screen)
        #expect(f.minY >= h.maxY + CardPlacement.headroom)
        #expect(f.maxX <= screen.maxX)          // nudged left at the right edge
    }

    @Test func goesBesideWhenNoRoomAbove() {
        let h = hush(x: 1700, y: 700, h: 300)   // perched high on a window
        let f = CardPlacement.frame(size: CGSize(width: 420, height: 480), avoiding: h, in: screen)
        #expect(f.maxX <= h.minX)               // to the left, where there's room
    }

    @Test func stacksEightPointsAboveAnAnswerCard() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let card = CGRect(x: 900, y: 200, width: 420, height: 300)
        let box = CardPlacement.frame(size: CGSize(width: 420, height: 46), stackedAbove: card, in: screen)
        #expect(box.minY == card.maxY + 8)
        #expect(box.midX == card.midX)
    }

    @Test func staysTwelvePointsInsideTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let hush = CGRect(x: 1400, y: 0, width: 40, height: 60)
        let f = CardPlacement.frame(size: CGSize(width: 420, height: 200), avoiding: hush, in: screen)
        #expect(f.maxX <= screen.maxX - 12)
    }
}
