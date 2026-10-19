import Foundation
import Testing
@testable import HushCore

@Suite struct Digest {
    let cwd = "/Users/x/Developer/hush"
    func ts(_ m: Double) -> String { TranscriptParser.iso.string(from: tenAM.addingTimeInterval(m * 60)) }
    func j(_ o: [String: Any]) -> Substring { Substring(String(decoding: try! JSONSerialization.data(withJSONObject: o), as: UTF8.self)) }

    func fixture() -> [Substring] {
        [
            j(["type": "ai-title", "aiTitle": "Fix the interrupt cap"]),
            j(["type": "user", "timestamp": ts(-30), "cwd": cwd, "message": ["role": "user", "content": "old prompt before you left"]]),
            j(["type": "user", "timestamp": ts(2), "cwd": cwd, "gitBranch": "main", "message": ["role": "user", "content": "make the cap configurable"]]),
            j(["type": "user", "timestamp": ts(2.1), "cwd": cwd, "isMeta": true, "message": ["role": "user", "content": "injected"]]),
            j(["type": "user", "timestamp": ts(2.2), "cwd": cwd, "message": ["role": "user", "content": "<command-name>/clear</command-name>"]]),
            j(["type": "assistant", "timestamp": ts(3), "cwd": cwd, "message": ["role": "assistant", "stop_reason": "tool_use", "content": [
                ["type": "tool_use", "name": "Edit", "input": ["file_path": "\(cwd)/Sources/HushCore/Settings.swift"]],
                ["type": "tool_use", "name": "Bash", "input": ["command": "swift test"]],
            ]]]),
            j(["type": "user", "timestamp": ts(3.5), "cwd": cwd, "message": ["role": "user", "content": [["type": "tool_result", "content": "ok"]]]]),
            j(["type": "assistant", "timestamp": ts(4), "cwd": cwd, "isSidechain": true, "message": ["role": "assistant", "content": [
                ["type": "tool_use", "name": "Write", "input": ["file_path": "\(cwd)/subagent.txt"]]]]]),
            j(["type": "assistant", "timestamp": ts(5), "cwd": cwd, "message": ["role": "assistant", "stop_reason": "tool_use", "content": [
                ["type": "tool_use", "name": "Bash", "input": ["command": "git commit -m 'cap'"]],
                ["type": "tool_use", "name": "Edit", "input": ["file_path": "\(cwd)/Sources/HushCore/Settings.swift"]],
            ]]]),
            j(["type": "pr-link", "timestamp": ts(6), "prUrl": "https://github.com/x/hush/pull/7"]),
            j(["type": "assistant", "timestamp": ts(7), "cwd": cwd, "message": ["role": "assistant", "stop_reason": "end_turn", "content": [
                ["type": "thinking", "thinking": "…"], ["type": "text", "text": "  Done: the cap is configurable and tests pass.  "]]]]),
            Substring("not json"),
        ]
    }

    @Test func digestsOnlyTheWindow() throws {
        let w = DateInterval(start: tenAM, end: tenAM.addingTimeInterval(3600))
        let d = try #require(TranscriptParser.digest(lines: fixture(), sessionID: "s1", window: w,
                                                     modified: tenAM.addingTimeInterval(7 * 60), now: tenAM.addingTimeInterval(3600)))
        #expect(d.title == "Fix the interrupt cap")
        #expect(d.prompts == 1 && d.firstPrompt == "make the cap configurable")       // meta + command tags skipped
        #expect(d.filesChanged == ["Sources/HushCore/Settings.swift"])               // deduped, sidechain ignored
        #expect(d.commands == 2 && d.commits == 1)
        #expect(d.pullRequests == ["https://github.com/x/hush/pull/7"])
        #expect(d.lastMessage == "Done: the cap is configurable and tests pass.")
        #expect(d.status == .finished && d.branch == "main" && d.project == "hush")
    }

    @Test func recentlyModifiedIsStillWorkingAndEmptyWindowsAreNil() {
        let w = DateInterval(start: tenAM, end: tenAM.addingTimeInterval(3600))
        let d = TranscriptParser.digest(lines: fixture(), sessionID: "s1", window: w,
                                        modified: tenAM.addingTimeInterval(3590), now: tenAM.addingTimeInterval(3600))
        #expect(d?.status == .working)
        let before = DateInterval(start: tenAM.addingTimeInterval(-7200), end: tenAM.addingTimeInterval(-3600))
        #expect(TranscriptParser.digest(lines: fixture(), sessionID: "s1", window: before, modified: tenAM, now: tenAM) == nil)
    }

    @Test func excerptIsCappedAndAwayRules() throws {
        let w = DateInterval(start: tenAM, end: tenAM.addingTimeInterval(3600))
        let d = try #require(TranscriptParser.digest(lines: fixture(), sessionID: "s1", window: w, modified: tenAM, now: tenAM.addingTimeInterval(3600)))
        #expect(d.excerpt.count < 3000 && d.excerpt.contains("Files changed: Sources/HushCore/Settings.swift"))
        #expect(!AwayRules.shouldOffer(awaySince: tenAM, now: tenAM.addingTimeInterval(300)))
        #expect(AwayRules.shouldOffer(awaySince: tenAM, now: tenAM.addingTimeInterval(700)))
        #expect(!AwayRules.shouldOffer(awaySince: nil, now: tenAM))
    }
}

@Suite struct RecentTurns {
    @Test func readsPromptsRepliesAndToolLines() {
        let lines: [Substring] = [
            #"{"type":"user","timestamp":"2026-10-19T10:00:00.000Z","message":{"content":"polish the panel"}}"#,
            #"{"type":"assistant","timestamp":"2026-10-19T10:00:05.000Z","message":{"content":[{"type":"text","text":"On it."},{"type":"tool_use","name":"Edit","input":{"file_path":"/x/hush/Sources/MenuPanel.swift"}}]}}"#,
            #"{"type":"assistant","timestamp":"2026-10-19T10:00:09.000Z","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"swift test\nmore"}}]}}"#,
            #"{"type":"user","message":{"content":[{"type":"tool_result","content":"ok"}]}}"#,
        ]
        let turns = TranscriptParser.recentTurns(lines: lines)
        #expect(turns.map(\.role) == [.you, .agent, .tool, .tool])
        #expect(turns[2].text == "Edit · MenuPanel.swift")
        #expect(turns[3].text == "Bash · swift test")
        #expect(TranscriptParser.recentTurns(lines: lines, limit: 2).map(\.text) == ["Edit · MenuPanel.swift", "Bash · swift test"])
    }
}
