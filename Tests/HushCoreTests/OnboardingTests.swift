import Foundation
import Testing
@testable import HushCore

@Suite struct OnboardingRules {
    @Test func buildersGetClaudeCodeOnlyWhenInstalled() {
        let p = OnboardingPreset.from([.builder], claudeInstalled: true)
        #expect(p.connect == [.calendar, .claudeCode, .askHotkey])
        #expect(OnboardingPreset.from([.builder], claudeInstalled: false).connect == [.calendar, .askHotkey])
        #expect(p.perch)
    }

    @Test func companyOnlyIsGentle() {
        let p = OnboardingPreset.from([.company], claudeInstalled: true)
        #expect(p.connect == [.askHotkey, .calendar])
        #expect(p.maxInterruptsPerDay == 3)
        #expect(!p.moods)
    }

    @Test func jugglerGetsCalendarFirstAndNoClaude() {
        let p = OnboardingPreset.from([.juggler], claudeInstalled: true)
        #expect(p.connect.first == .calendar)
        #expect(!p.connect.contains(.claudeCode))
    }

    @Test func noAnswerIsSafeDefaults() {
        let p = OnboardingPreset.from([], claudeInstalled: true)
        #expect(p.connect == [.calendar, .askHotkey])
        #expect(p.maxInterruptsPerDay == 5)
    }

    @Test func tipsOnlyAfterOnboardingInFirstWeekOnce() {
        var p = OnboardingProgress(firstLaunch: tenAM)
        #expect(!p.shouldShow(.envelope, now: tenAM))          // not finished yet
        p.finished = true
        #expect(p.shouldShow(.envelope, now: tenAM.addingTimeInterval(3600)))
        p.tipsShown.insert(.envelope)
        #expect(!p.shouldShow(.envelope, now: tenAM.addingTimeInterval(3600)))
        #expect(!p.shouldShow(.typingDuck, now: tenAM.addingTimeInterval(8 * 86_400)))  // after a week
        p.tipsOff = true
        #expect(!p.shouldShow(.typingDuck, now: tenAM))
    }

    @Test func progressRoundTripsAndChecklist() throws {
        var p = OnboardingProgress(firstLaunch: tenAM)
        p.personas = [.builder, .company]; p.connected = [.calendar]; p.lastStep = .connect
        let back = try JSONDecoder().decode(OnboardingProgress.self, from: JSONEncoder().encode(p))
        #expect(back == p)
        #expect(p.remaining(claudeInstalled: false) == [.askHotkey])
        #expect(p.shouldStart)
        p.skipped = true
        #expect(!p.shouldStart)
    }
}
