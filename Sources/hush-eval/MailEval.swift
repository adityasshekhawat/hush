import Foundation
import HushCore
import HushMac

// Mail triage eval (ADR-018): runs evals/mail.json through the same OnDeviceTriage the app uses and prints
// accuracy, gists and latency. On-device, so it's free:  swift run hush-eval --lane mail [--filter lunch]

struct MailCase: Decodable { var name: String; var from: String; var subject: String; var snippet: String; var expect: String }
struct MailSet: Decodable { var cases: [MailCase] }

func runMailEval(root: URL, filter: String?) async throws {
    let set = try JSONDecoder().decode(MailSet.self, from: Data(contentsOf: root.appendingPathComponent("evals/mail.json")))
    let cases = set.cases.filter { c in filter.map { (c.subject + " " + c.snippet).lowercased().contains($0) } ?? true }
    guard OnDeviceTriage.systemStatus == .on else {
        print("Apple's on-device model isn't available here (\(OnDeviceTriage.systemStatus)).")
        return
    }
    let triage = OnDeviceTriage(enabled: true)
    await triage.prewarm()
    print("Mail triage · \(MailTriage.version) · \(cases.count) mails\n")

    var right = 0, fellBack = 0, missed = 0, extra = 0
    var times: [Int] = []
    for (i, c) in cases.enumerated() {
        let item = InboxItem(id: "eval-\(i)", kind: .mail, senderName: c.name, senderAddress: c.from,
                             subject: c.subject, snippet: c.snippet, receivedAt: Date())
        let start = ContinuousClock.now
        let k = await triage.classify(item)
        let ms = Int((ContinuousClock.now - start) / .milliseconds(1))
        let gist = await triage.gist(for: item)
        times.append(ms)
        if k.modelVersion != MailTriage.version { fellBack += 1 }
        let ok = k.level.name == c.expect
        if ok { right += 1 } else if c.expect == "gentle" { missed += 1 } else { extra += 1 }
        let sure = k.confidence >= 0.7 ? "sure" : "unsure"
        print("\(ok ? "✓" : "✗") \(k.level.name.padding(toLength: 8, withPad: " ", startingAt: 0)) \(sure.padding(toLength: 7, withPad: " ", startingAt: 0)) \(String(format: "%5d", ms)) ms  \(c.subject)")
        print("                                  → \(gist)")
    }
    let sorted = times.sorted()
    let p50 = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    print("\n\(right)/\(cases.count) right · \(missed) real asks missed · \(extra) shown that could wait · \(fellBack) fell back to rules · p50 \(p50) ms")
}
