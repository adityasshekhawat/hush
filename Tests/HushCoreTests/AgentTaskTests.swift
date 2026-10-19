import Foundation
import Testing
@testable import HushCore

@Suite struct AskHush {
    let allowed = ["/Users/x/Developer/hush", "/Users/x/Developer/notes-api/"]

    @Test func repoPriority() {
        #expect(RepoChooser.choose(picked: "/Users/x/Developer/notes-api", recentSessionCwd: "/Users/x/Developer/hush",
                                   lastUsed: nil, allowed: allowed) == "/Users/x/Developer/notes-api")
        #expect(RepoChooser.choose(picked: nil, recentSessionCwd: "/Users/x/Developer/hush/Sources/Hush",
                                   lastUsed: "/Users/x/Developer/notes-api", allowed: allowed) == "/Users/x/Developer/hush")
        #expect(RepoChooser.choose(picked: nil, recentSessionCwd: "/tmp/elsewhere",
                                   lastUsed: "/Users/x/Developer/notes-api", allowed: allowed) == "/Users/x/Developer/notes-api")
        #expect(RepoChooser.choose(picked: nil, recentSessionCwd: nil, lastUsed: nil, allowed: allowed) == "/Users/x/Developer/hush")
    }

    @Test func neverReturnsAFolderYouHaventAllowed() {
        #expect(RepoChooser.choose(picked: "/etc", recentSessionCwd: "/Users/x", lastUsed: "/tmp", allowed: []) == nil)
        #expect(RepoChooser.choose(picked: "/Users/x/Developer/hushy", recentSessionCwd: nil, lastUsed: nil,
                                   allowed: ["/Users/x/Developer/hush"]) == "/Users/x/Developer/hush")   // not a prefix match
    }

    @Test func readOnlyProfileHasNoWriteTools() {
        let tools = ReadOnlyProfile.allowedTools
        for banned in ["Edit", "Write", "NotebookEdit", "WebFetch", "WebSearch", "Bash", "Bash(*)"] {
            #expect(!tools.contains(banned))
        }
        #expect(tools.allSatisfy { !$0.hasPrefix("Bash(") || $0.hasPrefix("Bash(git ") || $0.hasPrefix("Bash(gh ") })
    }

    @Test func taskLogRoundTrip() throws {
        let store = try HushStore(path: ":memory:")
        var t = AgentTask(startedAt: tenAM, repo: "/Users/x/Developer/hush", prompt: "what changed?", model: "sonnet")
        try store.save(t)
        t.status = .done; t.result = "Two commits."; t.toolsUsed = ["Bash", "Read"]; t.costUSD = 0.002; t.contextTokens = 9000
        try store.save(t)
        let log = try store.agentTasks(limit: 5)
        #expect(log.count == 1)
        #expect(log[0].status == .done && log[0].toolsUsed == ["Bash", "Read"] && log[0].repoName == "hush")
        try store.deleteAgentTasks()
        #expect(try store.agentTasks(limit: 5).isEmpty)
    }
}
