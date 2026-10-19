import Foundation
import HushCore
import HushMac

// Ask Hush eval (docs/lanes-plan.md § L2). Runs the eval set's asks through a lane with a real model and prints
// pass rate, cost and latency. Costs money on your Claude Code login, so it only runs when you ask.
//
//   swift run hush-eval                        quick lane, its default model, every quick case
//   swift run hush-eval --model sonnet         compare another model
//   swift run hush-eval --limit 5 --filter git
//   swift run hush-eval --lane repo --repo ~/Developer/hush    code questions (reports finish + cost, no grading)
//   swift run hush-eval --lane mail            mail triage on Apple's on-device model (free; MailEval.swift)
//   swift run hush-eval --lane pouch           "hand it to Hush" reworks on the on-device model (free; PouchEval.swift)

let args = Array(CommandLine.arguments.dropFirst())
@MainActor func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

let laneArg = option("--lane") ?? "quick"
if laneArg == "mail" {
    let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    try await runMailEval(root: here, filter: option("--filter")?.lowercased())
    exit(0)
}
if laneArg == "rules" {
    await runRulesEval()
    exit(0)
}
if laneArg == "pouch" {
    let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    try await runPouchEval(root: here, filter: option("--filter")?.lowercased())
    exit(0)
}
guard let lane = LaneID(rawValue: laneArg), lane == .quick || lane == .repo || lane == .route else {
    FileHandle.standardError.write(Data("--lane must be quick, repo or route\n".utf8)); exit(2)
}
let spec = LaneRegistry.spec(lane, modelOverride: option("--model"))
let limit = option("--limit").flatMap(Int.init) ?? .max
let filter = option("--filter")?.lowercased()
let repoPath = option("--repo").map { NSString(string: $0).expandingTildeInPath }
if lane == .repo && repoPath == nil {
    FileHandle.standardError.write(Data("--lane repo needs --repo <path>\n".utf8)); exit(2)
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
let set = try AskEvalSet.load(root.appendingPathComponent("evals/asks.json"))
let cases = set.cases
    .filter { (lane == .route || $0.lane == lane.rawValue) && !$0.ask.hasPrefix("@") }
    .filter { filter == nil || $0.ask.lowercased().contains(filter!) }
    .prefix(limit)

print("Lane \(lane.rawValue) · model \(spec.model) · \(cases.count) asks\n")

struct Row: Encodable { var ask: String; var pass: Bool; var problems: [String]; var costUSD: Double; var ms: Int; var answer: String }
final class Box: @unchecked Sendable { var shape: AnswerShape?; var routeData: Data?; var text = ""; var cost = 0.0; var ms = 0; var failure: String? }

var rows: [Row] = []
for c in cases {
    let o: ClaudeCodeRunner.Options
    if lane == .route {
        var r = ClaudeCodeRunner.Options(cwd: FileManager.default.temporaryDirectory, prompt: c.ask, allowedTools: [])
        r.apply(spec)
        r.systemPrompt = RouteCheck.systemPrompt(context: set.context(for: c), runningSessions: 2)
        r.jsonSchema = RouteCheck.jsonSchema(context: set.context(for: c))
        o = r
    } else if lane == .quick {
        o = LaneOptions.quick(c.ask, appName: set.context(for: c).appName, spec: spec)
    } else {
        o = LaneOptions.repo(c.ask, repo: repoPath!, spec: spec)
    }
    let box = Box()
    ClaudeCodeRunner(options: o).run { event in
        switch event {
        case .structured(let d): box.shape = try? JSONDecoder().decode(AnswerShape.self, from: d); box.routeData = d
        case .text(let t): box.text += t
        case .finished(let result, let cost, _, let ms, _):
            box.cost = cost; box.ms = ms
            if box.text.isEmpty { box.text = result }
        case .failed(let why): box.failure = why
        default: break
        }
    }
    var problems = box.failure.map { ["failed: \($0)"] } ?? []
    if problems.isEmpty, lane == .route {
        let picked = box.routeData.flatMap { RouteCheck.parse($0, question: c.ask, context: set.context(for: c)) }
        let got = picked.map { AskEvalSet.laneName($0.lane) } ?? "none"
        if got != c.lane { problems = ["picked \(got), wanted \(c.lane)"] }
        box.text = got + (picked.map { " (\($0.why))" } ?? "")
    } else if problems.isEmpty {
        problems = lane == .quick ? AskEvalSet.grade(box.shape, against: c) : (box.text.isEmpty ? ["empty answer"] : [])
    }
    let answer = box.shape?.plainText ?? box.text
    rows.append(Row(ask: c.ask, pass: problems.isEmpty, problems: problems, costUSD: box.cost, ms: box.ms, answer: answer))
    print("\(problems.isEmpty ? "✓" : "✗") \(c.ask)\(problems.isEmpty ? "" : "  → " + problems.joined(separator: "; "))")
}

guard !rows.isEmpty else { print("No cases matched."); exit(0) }
let passed = rows.filter(\.pass).count
let ms = rows.map(\.ms).sorted()
let cost = rows.map(\.costUSD).reduce(0, +)
print(String(format: "\nPassed %d/%d (%.0f%%) · total $%.3f · mean $%.4f · p50 %.1fs",
             passed, rows.count, 100 * Double(passed) / Double(rows.count), cost, cost / Double(rows.count),
             Double(ms[ms.count / 2]) / 1000))

let stamp = ISO8601DateFormatter().string(from: Date()).prefix(16).replacingOccurrences(of: ":", with: "")
let out = root.appendingPathComponent("evals/results/\(stamp)-\(lane.rawValue)-\(spec.model).json")
try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
try enc.encode(rows).write(to: out)
print("Saved \(out.path.replacingOccurrences(of: root.path + "/", with: ""))")
