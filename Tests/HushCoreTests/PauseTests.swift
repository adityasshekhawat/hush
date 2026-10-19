import Foundation
import Testing
@testable import HushCore

@Suite struct Pausing {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func lengthsEndWhereYoudExpect() {
        let now = Date(timeIntervalSince1970: 1_792_231_200)   // 10:00 UTC
        #expect(PauseLength.quarterHour.until(from: now, calendar: cal).timeIntervalSince(now) == 15 * 60)
        #expect(PauseLength.hour.until(from: now, calendar: cal).timeIntervalSince(now) == 60 * 60)
        let tomorrow = PauseLength.untilTomorrow.until(from: now, calendar: cal)
        #expect(cal.component(.hour, from: tomorrow) == 8)
        #expect(cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: tomorrow)).day == 1)
        // In the small hours, "until tomorrow" means the coming morning, not 31 hours away.
        let lateNight = cal.date(bySettingHour: 0, minute: 30, second: 0, of: now)!
        #expect(PauseLength.untilTomorrow.until(from: lateNight, calendar: cal).timeIntervalSince(lateNight) == 7.5 * 3600)
    }

    @Test func statusReadsPlainly() {
        let now = Date(timeIntervalSince1970: 1_792_231_200)
        #expect(PauseText.status(until: now.addingTimeInterval(3600), now: now, calendar: cal) == "Paused until 11:00")
        #expect(PauseText.status(until: PauseLength.untilTomorrow.until(from: now, calendar: cal), now: now, calendar: cal)
                == "Paused until tomorrow, 08:00")
    }

    @Test func pausedOrLockedHidesAndQueues() async throws {
        let e = DecisionEngine(store: try HushStore(path: ":memory:"), classifier: FixedClassifier(level: .gentle, confidence: 0.9))
        _ = try await e.setFocus(UserFocus(paused: true), now: tenAM)
        #expect(UserFocus(paused: true).hidesCharacter && UserFocus(locked: true).hidesCharacter)
        let d = try #require(await e.evaluate(mail("p1"), now: tenAM))
        #expect(d.outcome == .queued)
        let released = try await e.setFocus(.idle, now: tenAM.addingTimeInterval(60))
        #expect(released.map(\.outcome) == [.shown])
    }
}
