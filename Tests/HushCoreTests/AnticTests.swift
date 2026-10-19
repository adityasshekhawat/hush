import Foundation
import Testing
@testable import HushCore

@Suite struct Antics {
    let policy = AnticPolicy(calendar: utc)
    let longAgo = tenAM.addingTimeInterval(-3600)

    func ctx(_ now: Date = tenAM, focus: UserFocus = .idle, active: Bool = false, touched: Date? = nil,
             lastAsk: Date? = nil, asks: Int = 0, tuck: Date? = nil) -> AnticContext {
        AnticContext(now: now, focus: focus, hasActiveAppearance: active, lastTouched: touched ?? longAgo,
                     lastPatRequest: lastAsk, patRequestsToday: asks, lastTuckIn: tuck)
    }

    @Test func invitedReactionsPlayWhileTypingButNotInCalls() {
        #expect(policy.mayPlay(.cheeks, ctx(focus: UserFocus(typing: true))))
        #expect(!policy.mayPlay(.cheeks, ctx(focus: UserFocus(inCall: true))))
    }

    @Test func unpromptedNeverCompetesWithRealWork() {
        #expect(!policy.mayPlay(.patRequest, ctx(focus: UserFocus(typing: true))))
        #expect(!policy.mayPlay(.patRequest, ctx(active: true)))
        #expect(!policy.mayPlay(.patRequest, ctx(focus: UserFocus(away: true))))
        #expect(policy.mayPlay(.patRequest, ctx()))
    }

    @Test func patRequestAfterThirtyMinutesUntouched() {
        #expect(policy.shouldRequestPat(ctx(touched: tenAM.addingTimeInterval(-31 * 60))))
        #expect(!policy.shouldRequestPat(ctx(touched: tenAM.addingTimeInterval(-10 * 60))))
    }

    @Test func patRequestsAreCappedAndSpaced() {
        #expect(!policy.shouldRequestPat(ctx(asks: 3)))
        #expect(!policy.shouldRequestPat(ctx(lastAsk: tenAM.addingTimeInterval(-5 * 60))))
        #expect(policy.shouldRequestPat(ctx(lastAsk: tenAM.addingTimeInterval(-40 * 60), asks: 1)))
    }

    @Test func tuckInOncePerDayAfterSixThirty() {
        let evening = tenAM.addingTimeInterval(9 * 3600)  // 19:00
        #expect(!policy.shouldTuckIn(ctx(tenAM)))
        #expect(policy.shouldTuckIn(ctx(evening)))
        #expect(!policy.shouldTuckIn(ctx(evening, tuck: evening.addingTimeInterval(-600))))
        #expect(policy.shouldTuckIn(ctx(evening, tuck: evening.addingTimeInterval(-86_400))))
    }

    @Test func fridayDanceOnlyFridayEvening() {
        // 2026-10-17 is a Saturday; the 16th is a Friday.
        let fridayEvening = tenAM.addingTimeInterval(-86_400 + 9 * 3600)
        #expect(policy.shouldDance(ctx(fridayEvening)))
        #expect(!policy.shouldDance(ctx(tenAM.addingTimeInterval(9 * 3600))))
    }

    @Test func morningAfterLongBreakOrNewDay() {
        #expect(policy.isMorning(returningAt: tenAM, awaySince: tenAM.addingTimeInterval(-4 * 3600)))
        #expect(!policy.isMorning(returningAt: tenAM, awaySince: tenAM.addingTimeInterval(-600)))
        #expect(policy.isLate(tenAM.addingTimeInterval(13.5 * 3600)))  // 23:30
        #expect(!policy.isLate(tenAM))
    }
}

@Suite struct Shake {
    @Test func fastBackAndForthIsAShake() {
        var d = ShakeDetector()
        var t = 0.0, fired = false
        for leg in 0..<6 {
            for step in 0..<5 {
                let x = leg % 2 == 0 ? Double(step) * 30 : Double(4 - step) * 30
                fired = d.add(x: x, at: t) || fired
                t += 0.025
            }
        }
        #expect(fired)
    }

    @Test func slowOrSmallMovementIsNot() {
        var d = ShakeDetector()
        var fired = false
        for i in 0..<60 { fired = d.add(x: Double(i % 2) * 10, at: Double(i) * 0.03) || fired }  // tiny jitter
        for i in 0..<10 { fired = d.add(x: Double(i % 2) * 200, at: Double(i) * 1.0) || fired }  // slow
        #expect(!fired)
    }
}
