import Foundation
import HushCore

/// Runner options for each lane, shared by the app and `hush-eval` so the eval measures exactly what Ask Hush runs.
public enum LaneOptions {
    /// Quick lane: no tools, no repo, a neutral folder; the answer comes back as an AnswerShape.
    public static func quick(_ question: String, appName: String?, spec: LaneSpec) -> ClaudeCodeRunner.Options {
        var o = ClaudeCodeRunner.Options(cwd: FileManager.default.temporaryDirectory, prompt: question, allowedTools: [])
        o.jsonSchema = AnswerShape.jsonSchema
        o.systemPrompt = AnswerShape.systemPrompt + (appName.map { " The user is in \($0)." } ?? "")
        o.apply(spec)
        return o
    }

    /// Repo lane: read-only tools in an allowed repo.
    public static func repo(_ question: String, repo: String, spec: LaneSpec) -> ClaudeCodeRunner.Options {
        var o = ClaudeCodeRunner.Options(cwd: URL(fileURLWithPath: repo), prompt: question, allowedTools: ReadOnlyProfile.allowedTools)
        o.systemPrompt = ClaudeCodeRunner.Options.leanSystemPrompt + " " + ReadOnlyProfile.instructions
        o.apply(spec)
        return o
    }

    /// Do lane, step 1: no tools; the model returns a TaskPlan for the plan card.
    public static func doPlan(_ task: String, spec: LaneSpec) -> ClaudeCodeRunner.Options {
        var o = ClaudeCodeRunner.Options(cwd: FileManager.default.temporaryDirectory, prompt: task, allowedTools: [])
        o.jsonSchema = TaskPlan.jsonSchema
        o.systemPrompt = TaskPlan.systemPrompt
        o.apply(spec)
        o.maxTurns = 2
        o.maxBudgetUSD = 0.10
        o.timeout = 60
        return o
    }
}

extension ClaudeCodeRunner.Options {
    /// Model and caps from a lane spec.
    public mutating func apply(_ spec: LaneSpec) {
        model = spec.model
        maxTurns = spec.maxTurns
        maxBudgetUSD = spec.maxBudgetUSD
        timeout = spec.timeout
    }
}
