import Foundation
import Testing
@testable import HushCore

@Suite struct AppRouting {
    let all: Set<String> = Set(AppTarget.allCases.compactMap(\.bundleID))
    func ids(_ kind: AnswerKind, from app: String?, installed: Set<String>? = nil) -> [String] {
        ActionRanker.actions(for: ActionContext(kind: kind, frontmostApp: app, installed: installed ?? all,
                                                question: "q", answer: "a")).map(\.id)
    }

    @Test func formulaFromExcelPastesInExcel() {
        #expect(ids(.formula, from: "com.microsoft.Excel") == ["paste.excel", "copy", "open.sheets"])
    }

    @Test func formulaFromBrowserCopiesFirst() {
        #expect(ids(.formula, from: "ai.perplexity.comet") == ["open.excel", "copy", "open.sheets"])
        #expect(ids(.formula, from: nil, installed: []) == ["open.sheets", "copy", "continue"])
    }

    @Test func commandGoesToTheTerminalYouCameFrom() {
        #expect(ids(.command, from: "dev.warp.Warp-Stable").first == "send.warp")
        #expect(ids(.command, from: "com.apple.Terminal").first == "send.terminal")
        #expect(ids(.command, from: "com.google.Chrome").first == "send.warp")      // preferred installed terminal
        #expect(ids(.command, from: nil, installed: ["com.apple.Terminal"]).first == "send.terminal")
    }

    @Test func repoAnswersOfferCursorOnlyWhenInstalled() {
        #expect(ids(.repo, from: nil).first == "ask.cursor")
        #expect(ids(.repo, from: nil, installed: []) == ["copy", "continue"])
    }

    @Test func notesGoBackWhereYouWrite() {
        #expect(ids(.steps, from: "notion.id").first == "save.notion")
        #expect(ids(.prose, from: "md.obsidian").first == "save.obsidian")
        #expect(ids(.fact, from: "com.google.Chrome") == ["copy", "continue"])
    }

    @Test func neverMoreThanThreeAndCopyAlwaysThere() {
        for k in [AnswerKind.formula, .command, .fact, .steps, .prose, .repo] {
            for app in [nil, "com.microsoft.Excel", "dev.warp.Warp-Stable", "notion.id", "md.obsidian", "com.todesktop.230313mzl4w4u92"] {
                let a = ids(k, from: app)
                #expect(a.count <= 3 && a.contains("copy"), "\(k) from \(app ?? "nil"): \(a)")
            }
        }
    }

    @Test func deepLinksAreEncoded() {
        let c = ActionContext(kind: .repo, frontmostApp: nil, installed: all, question: "fix & ship?", answer: "line 1\nline 2")
        guard case .copyAndOpen(let url) = ActionRanker.askCursor(c).mechanism else { Issue.record("not a link"); return }
        #expect(url.absoluteString.hasPrefix("cursor://anysphere.cursor-deeplink/prompt?text=fix%20%26%20ship%3F"))
        #expect(!url.absoluteString.contains("\n"))
    }
}

@Suite struct WardrobeCatalogue {
    @Test func everySlotHasPiecesAndCapeHasTwoLayers() {
        #expect(Wardrobe.pieces.count == 46)
        #expect(Wardrobe.free.count == 15)
        #expect(Wardrobe.piece("cape")?.layers == ["pack-cape-back", "pack-neck-cape-clasp"])
        #expect(Set(Wardrobe.pieces.map(\.id)).count == Wardrobe.pieces.count)
        #expect(Wardrobe.layers(for: [.head: "beanie", .face: "shades"]) == ["head-beanie", "face-shades"])
    }
}
