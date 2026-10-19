import Foundation
import HushCore
import HushMac

// "Tell Hush what matters" eval (ADR-026): plain words in, rule sentences out, parsed in code. Free (on-device).
//   swift run hush-eval --lane rules
func runRulesEval() async {
    let cases: [(String, [String])] = [
        ("anything from acme.com matters, and hide the newsletters from shop.com",
         ["I'll always show you mail from anyone at acme.com.", "I'll hold back mail from anyone at shop.com."]),
        ("tap the glass when boss@acme.com writes", ["I'll always tap the glass for mail from boss@acme.com."]),
        ("I never want to see agent updates from the scratch project", ["I'll hold back agent updates in scratch."]),
        ("my manager and invoices", []),
        ("always nudge me hard for meetings", ["I'll always tap the glass for meeting reminders."]),
    ]
    guard OnDeviceTriage.systemStatus == .on else { print("Apple's on-device model isn't available here."); return }
    let triage = OnDeviceTriage(enabled: true)
    var right = 0
    for (input, expected) in cases {
        let sentences = await triage.suggestRules(from: input)
        let got = RuleSuggestions.rules(from: sentences, now: Date()).map(RuleText.sentence)
        let ok = Set(got) == Set(expected)
        if ok { right += 1 }
        print("\(ok ? "✓" : "✗") \(input)\n    model: \(sentences)\n    rules: \(got)\n")
    }
    print("\(right)/\(cases.count) right")
}
