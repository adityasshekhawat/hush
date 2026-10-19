import Foundation

/// Asking Hush a follow-up on the answer that's showing. The next question keeps the same lane and carries the last
/// few turns as context. Capped, so Ask Hush stays a doorway: deeper conversations belong in ChatGPT or Claude.
public struct FollowUp: Sendable, Equatable {
    public struct Turn: Sendable, Equatable {
        public var question: String
        public var answer: String
        public init(question: String, answer: String) { self.question = question; self.answer = answer }
    }

    public static let maxTurns = 3
    static let maxAnswerChars = 1500

    /// Oldest first, at most `maxTurns`.
    public var turns: [Turn]
    public var lane: AskLane

    public init(turns: [Turn], lane: AskLane) {
        self.turns = Array(turns.suffix(Self.maxTurns))
        self.lane = lane
    }

    /// The thread so far plus the answer on the card.
    public func adding(_ turn: Turn) -> FollowUp { FollowUp(turns: turns + [turn], lane: lane) }

    public var lastQuestion: String { turns.last?.question ?? "" }
    /// At the cap: the card suggests carrying on in an assistant instead.
    public var isFull: Bool { turns.count >= Self.maxTurns }

    /// What the model receives: the earlier turns, then the new question.
    public func prompt(_ question: String) -> String {
        let earlier = turns.map { t in
            let a = t.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Q: \(t.question)\nA: \(a.count > Self.maxAnswerChars ? String(a.prefix(Self.maxAnswerChars)) + "…" : a)"
        }.joined(separator: "\n\n")
        return "Earlier in this conversation:\n\(earlier)\n\nFollow-up: \(question)"
    }
}
