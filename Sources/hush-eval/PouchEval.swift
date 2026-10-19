import Foundation
import HushCore
import HushMac

// Hand it to Hush eval (ADR-019): runs evals/pouch.json through the same OnDeviceRewriter the app uses.
// On-device, so it's free:  swift run hush-eval --lane pouch [--filter offsite]

struct PouchCase: Decodable { var verb: PouchVerb; var text: String }
struct PouchSet: Decodable { var cases: [PouchCase] }

/// What a good rework must keep: shorter is shorter, bullets are bullets, simpler doesn't bloat, numbers survive.
func pouchProblems(_ out: String, for c: PouchCase) -> [String] {
    var problems: [String] = []
    let ratio = Double(out.count) / Double(max(1, c.text.count))
    switch c.verb {
    case .shorter where ratio > 0.75: problems.append("not shorter (\(Int(ratio * 100))%)")
    case .simpler where ratio > 1.2: problems.append("longer (\(Int(ratio * 100))%)")
    case .bullets where !out.split(separator: "\n").allSatisfy({ $0.hasPrefix("- ") }): problems.append("not all bullets")
    default: break
    }
    let numbers = { (s: String) in Set(s.matches(of: /\d+(?:[.:,]\d+)*/).map { String($0.output) }) }
    let lost = numbers(c.text).subtracting(numbers(out))
    if !lost.isEmpty { problems.append("lost \(lost.sorted().joined(separator: ", "))") }
    return problems
}

func runPouchEval(root: URL, filter: String?) async throws {
    let set = try JSONDecoder().decode(PouchSet.self, from: Data(contentsOf: root.appendingPathComponent("evals/pouch.json")))
    let cases = set.cases.filter { c in filter.map { c.text.lowercased().contains($0) } ?? true }
    guard OnDeviceTriage.systemStatus == .on else {
        print("Apple's on-device model isn't available here (\(OnDeviceTriage.systemStatus)).")
        return
    }
    let rewriter = OnDeviceRewriter()
    print("Hand it to Hush · \(cases.count) snippets\n")
    var passed = 0, failed = 0
    var times: [Int] = []
    for c in cases {
        if Pouch.check(c.text) == .code {
            passed += 1
            print("✓ \(c.verb.title) · left alone as code\n")
            continue
        }
        await rewriter.prewarm()
        let start = ContinuousClock.now
        do {
            let out = try await rewriter.rework(c.text, verb: c.verb)
            let ms = Int((ContinuousClock.now - start) / .milliseconds(1))
            times.append(ms)
            let problems = pouchProblems(out, for: c)
            if problems.isEmpty { passed += 1 } else { failed += 1 }
            print("\(problems.isEmpty ? "✓" : "✗") \(c.verb.title) · \(ms) ms\(problems.isEmpty ? "" : " · " + problems.joined(separator: "; "))")
            print("  in:  \(c.text.prefix(110).replacingOccurrences(of: "\n", with: " "))…")
            print("  out: \(out.replacingOccurrences(of: "\n", with: "\n       "))\n")
        } catch {
            failed += 1
            print("✗ \(c.verb.title) · \(error)\n")
        }
    }
    let sorted = times.sorted()
    print("\(passed)/\(cases.count) passed · \(failed) failed · p50 \(sorted.isEmpty ? 0 : sorted[sorted.count / 2]) ms")
}
