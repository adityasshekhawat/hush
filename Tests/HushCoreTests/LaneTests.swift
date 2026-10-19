import Foundation
import Testing
@testable import HushCore

@Suite struct Lanes {
    @Test func defaultsMatchTheEarlierHardCodedValues() {
        #expect(LaneRegistry.defaultSpec(.quick).model == "haiku")
        #expect(LaneRegistry.defaultSpec(.repo).model == "sonnet")
        #expect(LaneRegistry.defaultSpec(.repo).maxTurns == 15)
        #expect(LaneRegistry.defaultSpec(.summarise).maxBudgetUSD == 0.05)
        #expect(LaneID.allCases.filter { $0 != .doIt }.allSatisfy { LaneRegistry.defaultSpec($0).approval == .none })
        #expect(LaneRegistry.defaultSpec(.doIt).approval == .planAndIrreversible)
    }

    @Test func overrideReplacesOnlyTheModel() {
        let s = LaneRegistry.spec(.quick, modelOverride: "sonnet")
        #expect(s.model == "sonnet")
        #expect(s.maxTurns == 2)
        #expect(LaneRegistry.spec(.repo, modelOverride: "claude-opus-5-5").model == "claude-opus-5-5")
    }

    @Test func badOverridesAreIgnored() {
        for bad in [nil, "", "  ", "haiku; rm -rf", "--dangerous flag"] {
            #expect(LaneRegistry.spec(.quick, modelOverride: bad).model == "haiku")
        }
    }
}
