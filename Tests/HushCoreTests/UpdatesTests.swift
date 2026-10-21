import Foundation
import Testing
@testable import HushCore

@Suite struct NewVersions {
    let now = Date(timeIntervalSince1970: 1_792_231_200)

    @Test func readsGitHubsLatestRelease() {
        let json = #"{"tag_name":"v0.2.0","html_url":"https://github.com/adityasshekhawat/hush/releases/tag/v0.2.0","draft":false,"prerelease":false}"#
        #expect(Updates.release(fromJSON: Data(json.utf8)) == .init(version: "0.2.0",
                                                                       page: URL(string: "https://github.com/adityasshekhawat/hush/releases/tag/v0.2.0")!))
        let pre = #"{"tag_name":"v0.3.0","html_url":"https://github.com/x","prerelease":true}"#
        #expect(Updates.release(fromJSON: Data(pre.utf8)) == nil)
        // Only GitHub pages open from the panel.
        let elsewhere = #"{"tag_name":"v0.3.0","html_url":"https://example.com/x"}"#
        #expect(Updates.release(fromJSON: Data(elsewhere.utf8)) == nil)
        #expect(Updates.release(fromJSON: Data(#"{"message":"Not Found"}"#.utf8)) == nil)
        #expect(Updates.release(fromJSON: Data("nonsense".utf8)) == nil)
    }

    @Test func comparesVersionsByNumber() {
        #expect(Updates.isNewer("0.2.0", than: "0.1.0"))
        #expect(Updates.isNewer("v0.10.0", than: "0.9.3"))
        #expect(Updates.isNewer("1.0", than: "0.9.9"))
        #expect(!Updates.isNewer("0.1.0", than: "0.1.0"))
        #expect(!Updates.isNewer("0.1", than: "0.1.0"))
        #expect(!Updates.isNewer("0.0.9", than: "0.1.0"))
        #expect(!Updates.isNewer("0.2.0-beta", than: "0.1.0"))
        #expect(Updates.normalized("v1.2.3") == "1.2.3")
        #expect(Updates.normalized("latest") == nil)
    }

    @Test func checksDailyOnlyWithYourYes() {
        #expect(!Updates.shouldCheck(consent: nil, lastCheck: nil, now: now))
        #expect(!Updates.shouldCheck(consent: false, lastCheck: nil, now: now))
        #expect(Updates.shouldCheck(consent: true, lastCheck: nil, now: now))
        #expect(!Updates.shouldCheck(consent: true, lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(Updates.shouldCheck(consent: true, lastCheck: now.addingTimeInterval(-21 * 3600), now: now))
        // A clock that went backwards doesn't stop checks forever.
        #expect(Updates.shouldCheck(consent: true, lastCheck: now.addingTimeInterval(3600), now: now))
    }

    @Test func updateScriptPullsAndRebuildsYourClone() {
        let s = Updates.updateScript(folder: "/Users/a/My Projects/it's hush")
        #expect(s.contains(#"cd '/Users/a/My Projects/it'\''s hush' || exit 1"#))
        #expect(s.contains("git pull --ff-only && ./scripts/bundle.sh"))
    }
}
