import Foundation
import HushCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Reworks copied text with Apple's on-device model for "hand it to Hush" (ADR-019). Runs on this Mac only.
/// Uses the guardrails Apple provides for transforming the user's own text, so ordinary content isn't refused.
public actor OnDeviceRewriter {
    public enum Failure: Error, Equatable {
        /// Apple Intelligence is off or the model isn't ready: offer the hand-off instead.
        case unavailable
        case timedOut
        /// Nothing usable came back (empty, unchanged, refused).
        case noResult
    }

    /// Longer than triage: a full 6,000-character rework can take several seconds.
    static let timeout: Duration = .seconds(20)
    private var spare: AnyObject?

    public init() {}

    /// Warm a session while you pick a verb.
    public func prewarm() {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), spare == nil, OnDeviceTriage.systemStatus == .on else { return }
        let session = Self.session()
        session.prewarm()
        spare = session
        #endif
    }

    public func rework(_ text: String, verb: PouchVerb) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), OnDeviceTriage.systemStatus == .on else { throw Failure.unavailable }
        let session = (spare as? LanguageModelSession) ?? Self.session()
        spare = nil
        let started = ContinuousClock.now
        let raw: String?
        do {
            raw = try await OnDeviceTriage.withTimeout(Self.timeout) { try await Self.respond(text, verb: verb, in: session) }
        } catch {
            Self.log("pouch: \(verb.rawValue) failed (\(error.localizedDescription))")
            throw Failure.noResult
        }
        let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
        guard let raw else { Self.log("pouch: \(verb.rawValue) timed out"); throw Failure.timedOut }
        guard let out = Pouch.clean(raw, verb: verb, original: text) else {
            Self.log("pouch: \(verb.rawValue) gave nothing usable in \(ms) ms")
            throw Failure.noResult
        }
        // Lengths only; the text itself is never logged.
        Self.log("pouch: \(verb.rawValue) \(text.count) → \(out.count) chars in \(ms) ms")
        return out
        #else
        throw Failure.unavailable
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func session() -> LanguageModelSession {
        LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
                             instructions: Pouch.instructions)
    }

    @available(macOS 26.0, *)
    private static func respond(_ text: String, verb: PouchVerb, in session: LanguageModelSession) async throws -> String {
        let root = DynamicGenerationSchema(name: "Reworked", properties: [
            .init(name: Pouch.resultField, description: Pouch.resultGuide, schema: DynamicGenerationSchema(type: String.self)),
        ])
        let schema = try GenerationSchema(root: root, dependencies: [])
        let response = try await session.respond(to: Pouch.prompt(text, verb: verb), schema: schema,
                                                 options: GenerationOptions(samplingMode: .greedy))
        return try response.content.value(String.self, forProperty: Pouch.resultField)
    }
    #endif

    private static func log(_ line: String) { Task { @MainActor in DiagnosticsLog.write(line) } }
}
