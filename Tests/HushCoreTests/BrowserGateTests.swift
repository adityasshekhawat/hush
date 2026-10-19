import Foundation
import Testing
@testable import HushCore

@Suite struct BrowserGateRules {
    let plan = TaskPlan(summary: "Make a sheet", domains: ["sheets.google.com", "google.com"],
                        steps: [.init(text: "Open sheets.new", irreversible: false)])
    func decide(_ tool: String, _ input: [String: Any] = [:], _ clicks: BrowserGate.ClickPolicy = .askEvery) -> BrowserGate.Decision {
        BrowserGate.decide(tool: "mcp__claude-in-chrome__" + tool, input: input, plan: plan, clicks: clicks)
    }

    @Test func lookingIsAlwaysAllowed() {
        #expect(decide("read_page") == .allow)
        #expect(decide("get_page_text") == .allow)
        #expect(decide("computer", ["action": "screenshot"]) == .allow)
        #expect(decide("browser_batch", ["actions": [["name": "computer", "input": ["action": "scroll"]],
                                                     ["name": "read_page", "input": [:]]]]) == .allow)
    }

    @Test func riskyToolsAreBlocked() {
        for t in ["javascript_tool", "file_upload", "upload_image", "shortcuts_execute", "switch_browser"] {
            guard case .deny = decide(t) else { Issue.record("\(t) should be denied"); continue }
        }
        guard case .deny = BrowserGate.decide(tool: "Bash", input: [:], plan: plan, clicks: .allowAfterApproval) else {
            Issue.record("non-browser tools must be denied"); return
        }
        guard case .deny = decide("some_new_tool") else { Issue.record("unknown tools must be denied"); return }
    }

    @Test func navigationStaysOnPlanSites() {
        #expect(decide("navigate", ["url": "https://sheets.google.com/create"]) == .allow)
        #expect(decide("navigate", ["url": "docs.google.com"]) == .allow)          // subdomain of google.com
        #expect(decide("navigate", ["url": "back"]) == .allow)
        guard case .ask = decide("navigate", ["url": "https://evil-google.com"]) else { Issue.record("lookalike host"); return }
        guard case .ask = decide("navigate", ["url": "https://example.org"]) else { Issue.record("off-plan host"); return }
        guard case .deny = decide("navigate", ["url": "file:///etc/passwd"]) else { Issue.record("file URL"); return }
        guard case .deny = decide("navigate", ["url": "javascript:alert(1)"]) else { Issue.record("js URL"); return }
    }

    @Test func batchesAreCheckedItemByItem() {
        let offPlan: [String: Any] = ["actions": [["name": "computer", "input": ["action": "left_click"]],
                                                  ["name": "navigate", "input": ["url": "https://example.org", "tabId": 1]]]]
        guard case .ask = decide("browser_batch", offPlan, .allowAfterApproval) else { Issue.record("navigate in a batch must be site-checked"); return }
        guard case .deny = decide("browser_batch", ["actions": [["name": "javascript_tool", "input": [:]]]], .allowAfterApproval) else {
            Issue.record("blocked tool in a batch"); return
        }
        guard case .deny = decide("browser_batch", ["actions": [["name": "browser_batch", "input": [:]]]]) else { Issue.record("nesting"); return }
        guard case .deny = decide("browser_batch", ["actions": []]) else { Issue.record("empty"); return }
    }

    @Test func clickPolicyDecidesClicksAndTyping() {
        guard case .ask(let why) = decide("computer", ["action": "type", "text": "hello"]) else { Issue.record("type"); return }
        #expect(why.contains("hello"))
        guard case .ask = decide("form_input") else { Issue.record("form"); return }
        guard case .ask(let q) = decide("computer", ["action": "left_click", "action_summary": "Sends the reply"]) else { Issue.record("click"); return }
        #expect(q == "Sends the reply")
        guard case .ask = decide("browser_batch", ["actions": [["name": "computer", "input": ["action": "left_click"]]]]) else { Issue.record("batch"); return }
        #expect(decide("computer", ["action": "left_click"], .allowAfterApproval) == .allow)
        #expect(decide("form_input", [:], .allowAfterApproval) == .allow)
    }

    @Test func spotsBrowserTasksNotQuestions() {
        #expect(DoIntent.matches("make a google sheet of these numbers"))
        #expect(!DoIntent.matches("what's the formula for XLOOKUP in google sheets"))
        #expect(!DoIntent.matches("find all files larger than 100MB"))
        #expect(!DoIntent.matches("add a page break in Notion"))
        #expect(!DoIntent.matches("open the formula bar in excel"))     // "form" only matches as a whole word
    }

    @Test func planDecodesFromModelJSON() throws {
        let json = #"{"summary":"s","domains":["a.com"],"steps":[{"text":"Send it","irreversible":true}]}"#
        let p = try JSONDecoder().decode(TaskPlan.self, from: Data(json.utf8))
        #expect(p.hasIrreversibleSteps)
        #expect(try JSONSerialization.jsonObject(with: Data(TaskPlan.jsonSchema.utf8)) is [String: Any])
    }
}

@Suite struct TaskBrowserPick {
    @Test func prefersYourPickThenARunningOneWithTheExtension() {
        #expect(TaskBrowser.pick(preferred: .comet, withExtension: [.chrome, .comet], running: [.chrome]) == .comet)
        #expect(TaskBrowser.pick(preferred: nil, withExtension: [.chrome, .comet], running: [.comet]) == .comet)
        #expect(TaskBrowser.pick(preferred: nil, withExtension: [.comet], running: []) == .comet)
        #expect(TaskBrowser.pick(preferred: .arc, withExtension: [.comet], running: []) == .comet)   // pick lacks the extension
        #expect(TaskBrowser.pick(preferred: nil, withExtension: [], running: [.chrome]) == nil)
    }
}

@Suite struct BrowserResult {
    @Test func splitsTheResultPageOffTheLastLine() {
        let r = TaskPlan.parseResult("Made the sheet with 3 rows.\nIt's in your Drive.\nURL: https://docs.google.com/spreadsheets/d/abc")
        #expect(r.text == "Made the sheet with 3 rows.\nIt's in your Drive.")
        #expect(r.url?.host == "docs.google.com")
        #expect(TaskPlan.parseResult("Done.\nURL: javascript:alert(1)").url == nil)
        #expect(TaskPlan.parseResult("Done, nothing to open.").url == nil)
    }
}
