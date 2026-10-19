import Foundation
import Testing
@testable import HushCore

@Suite struct RareFindRules {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    func at(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
    func ctx(_ now: String, busy: Bool = false, installed: String = "2025-06-01T09:00:00Z") -> RareContext {
        RareContext(now: at(now), calendar: cal, busy: busy, installDate: at(installed))
    }

    @Test func luckyMorningBirdAndTheDailyCap() {
        var s = RareState()
        #expect(RareFinds.roll(.morning, state: &s, ctx: ctx("2026-10-19T08:00:00Z"), random: { 0 }) == ["bird"])
        #expect(RareFinds.panelLine(s, now: at("2026-10-19T09:00:00Z"), calendar: cal) == "New find: a little bird")
        // One find a day, whatever else rolls.
        #expect(RareFinds.roll(.drag, state: &s, ctx: ctx("2026-10-19T09:00:00Z"), random: { 0 }).isEmpty)
        #expect(RareFinds.panelLine(s, now: at("2026-10-20T09:00:00Z"), calendar: cal) == nil)
        // The bird leaves at noon, or when dragged.
        #expect(RareFinds.expire(&s, now: at("2026-10-19T12:00:01Z")) == ["bird"])
    }

    @Test func nothingWhileBusyAndOneRollPerMoment() {
        var s = RareState()
        #expect(RareFinds.roll(.morning, state: &s, ctx: ctx("2026-10-19T08:00:00Z", busy: true), random: { 0 }).isEmpty)
        var t = RareState()
        #expect(RareFinds.roll(.morning, state: &t, ctx: ctx("2026-10-19T08:00:00Z"), random: { 0.9 }).isEmpty)
        #expect(RareFinds.roll(.morning, state: &t, ctx: ctx("2026-10-19T08:30:00Z"), random: { 0 }).isEmpty)  // already rolled today
    }

    @Test func datedFindsAndMilestones() {
        var s = RareState()
        #expect(RareFinds.roll(.dayStart, state: &s, ctx: ctx("2026-06-01T07:00:00Z")) == ["partyHat", "balloon"])
        var v = RareState()
        #expect(RareFinds.roll(.dayStart, state: &v, ctx: ctx("2027-02-14T07:00:00Z")) == ["heartGlasses"])
        var m = RareState()
        #expect(RareFinds.roll(.askCount(99), state: &m, ctx: ctx("2026-10-19T10:00:00Z")).isEmpty)
        #expect(RareFinds.roll(.askCount(100), state: &m, ctx: ctx("2026-10-19T10:00:00Z")) == ["monocle"])
        var l = RareState()
        #expect(RareFinds.roll(.firstUnlock(daysAway: 6, weekday: 3, hour: 9), state: &l, ctx: ctx("2026-10-20T09:00:00Z")) == ["lei"])
    }

    @Test func hintsAppearOnlyAfterAnotherOfTheTier() {
        var s = RareState()
        let snail = RareFinds.find("snail")!
        #expect(!RareFinds.showsHint(snail, state: s))
        s.found["bird"] = Date()
        #expect(RareFinds.showsHint(snail, state: s))
        #expect(RareFinds.all.count == 14)
        #expect(RareFinds.all.allSatisfy { Wardrobe.piece($0.id)?.source == .rare })
    }
}
