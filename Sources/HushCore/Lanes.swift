import Foundation

/// Models as settings (docs/lanes-plan.md): each model-backed job is a lane with its own model and caps.
/// Defaults live here; the model can be overridden per lane. Nothing else should hard-code a model.

public enum LaneID: String, Sendable, CaseIterable, Codable {
    case quick, repo, summarise
    /// The smarter router's check when the rules aren't sure.
    case route
    /// Browser tasks (L3, off until enabled).
    case doIt = "do"

    public var displayName: String {
        switch self {
        case .quick: "Quick answers"
        case .repo: "Code questions"
        case .summarise: "Digest summaries"
        case .route: "Routing"
        case .doIt: "Browser tasks"
        }
    }
}

/// Aliases the Claude CLI maps to the newest model of each tier, so upgrades arrive for free.
public enum ModelAlias: String, Sendable, CaseIterable {
    case haiku, sonnet, opus

    public var displayName: String {
        switch self {
        case .haiku: "Haiku (fast)"
        case .sonnet: "Sonnet (balanced)"
        case .opus: "Opus (strongest)"
        }
    }
}

public struct LaneSpec: Sendable, Equatable {
    public enum Approval: Sendable, Equatable {
        case none
        /// A plan card before the run, plus a pause before anything irreversible (the "do it" lane, L3).
        case planAndIrreversible
    }

    public var id: LaneID
    /// An alias (`haiku`) or a pinned model id.
    public var model: String
    public var maxTurns: Int
    public var maxBudgetUSD: Double
    public var timeout: TimeInterval
    public var approval: Approval
}

public enum LaneRegistry {
    public static func defaultSpec(_ id: LaneID) -> LaneSpec {
        switch id {
        case .quick: LaneSpec(id: id, model: "haiku", maxTurns: 2, maxBudgetUSD: 0.05, timeout: 40, approval: .none)
        case .repo: LaneSpec(id: id, model: "sonnet", maxTurns: 15, maxBudgetUSD: 0.30, timeout: 150, approval: .none)
        case .summarise: LaneSpec(id: id, model: "haiku", maxTurns: 2, maxBudgetUSD: 0.05, timeout: 40, approval: .none)
        case .route: LaneSpec(id: id, model: "haiku", maxTurns: 2, maxBudgetUSD: 0.02, timeout: 15, approval: .none)
        // The timeout includes time spent waiting for your taps.
        case .doIt: LaneSpec(id: id, model: "sonnet", maxTurns: 30, maxBudgetUSD: 1.00, timeout: 600, approval: .planAndIrreversible)
        }
    }

    /// The lane with the user's model override applied (blank or malformed overrides are ignored).
    public static func spec(_ id: LaneID, modelOverride: String?) -> LaneSpec {
        var s = defaultSpec(id)
        if let m = modelOverride?.trimmingCharacters(in: .whitespaces), isValidModel(m) { s.model = m }
        return s
    }

    /// An alias, or a model id like `claude-sonnet-5-5` (letters, digits, dots, dashes).
    public static func isValidModel(_ m: String) -> Bool {
        !m.isEmpty && m.count <= 64 && m.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
    }
}
