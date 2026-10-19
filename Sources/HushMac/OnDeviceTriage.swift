import Foundation
import HushCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model as Hush's classifier and gist writer (ADR-001, ADR-018): one call per mail decides
/// ambient or gentle, says whether it's sure, and writes the gist, so the card opens instantly (FR-4, FR-9).
/// Runs entirely on this Mac. Whenever the model is off, unavailable, slow or refuses, the rules answer instead,
/// so Hush never waits on it (PRD: "the character never waits on a model").
public actor OnDeviceTriage: AttentionClassifier, GistWriter {
    /// What Settings shows. `on` means mail is judged by the model right now.
    public enum Status: Sendable, Equatable {
        case on, turnedOff, appleIntelligenceOff, notReady, unsupported
    }

    public nonisolated let version = MailTriage.version
    /// Past this the rules answer instead; a warm call takes about 1.3 s on an M-series Mac.
    static let timeout: Duration = .seconds(4)

    private let rules: any AttentionClassifier
    private let plain: any GistWriter
    private var enabled: Bool
    /// Gists written during classification, collected by `gist(for:)` (only shown items ask for one).
    private var gists: [String: String] = [:]
    /// A session warmed up ahead of the next mail; each mail gets a fresh one so nothing carries over.
    private var spare: AnyObject?

    public init(enabled: Bool, rules: any AttentionClassifier = RulesOnlyClassifier(),
                plain: any GistWriter = SubjectGistWriter()) {
        self.enabled = enabled
        self.rules = rules
        self.plain = plain
    }

    public func setEnabled(_ on: Bool) {
        enabled = on
        if !on { spare = nil }
    }

    public func status() -> Status { enabled ? Self.systemStatus : .turnedOff }

    /// Whether this Mac can run the model at all, ignoring the user's setting.
    public nonisolated static var systemStatus: Status {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .on
            case .unavailable(.appleIntelligenceNotEnabled): return .appleIntelligenceOff
            case .unavailable(.modelNotReady): return .notReady
            case .unavailable: return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    /// Load the model ahead of the first mail (the first call is ~5 s cold, ~1.3 s warm).
    public func prewarm() {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), enabled, spare == nil, Self.systemStatus == .on else { return }
        let session = LanguageModelSession(instructions: MailTriage.instructions)
        session.prewarm()
        spare = session
        #endif
    }

    public func classify(_ item: InboxItem) async -> Classification {
        guard item.kind == .mail, enabled, let answer = await ask(item) else { return await rules.classify(item) }
        if gists.count > 100 { gists.removeAll() }
        if let g = answer.gist { gists[item.id] = g }
        return answer.classification
    }

    public func gist(for item: InboxItem) async -> String {
        if let g = gists.removeValue(forKey: item.id) { return g }
        return await plain.gist(for: item)
    }

    struct Answer: Sendable {
        var classification: Classification
        var gist: String?
    }

    private func ask(_ item: InboxItem) async -> Answer? {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), Self.systemStatus == .on else { return nil }
        let session = (spare as? LanguageModelSession) ?? LanguageModelSession(instructions: MailTriage.instructions)
        spare = nil
        let started = ContinuousClock.now
        defer { prewarm() }
        do {
            let answer = try await Self.withTimeout(Self.timeout) { try await Self.respond(to: item, in: session) }
            let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
            guard let answer else {
                Self.log("triage: model took over \(Self.timeout); rules answered")
                return nil
            }
            Self.log("triage: \(answer.classification.level.name) sure=\(answer.classification.confidence > 0.7) in \(ms) ms")
            return answer
        } catch {
            // Guardrails, an unsupported language, or the model going away: the rules take it.
            Self.log("triage: model failed (\(error.localizedDescription)); rules answered")
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func respond(to item: InboxItem, in session: LanguageModelSession) async throws -> Answer {
        typealias F = MailTriage.Field
        let root = DynamicGenerationSchema(name: "MailTriage", properties: [
            .init(name: F.level, description: F.levelGuide, schema: DynamicGenerationSchema(name: "Level", anyOf: F.levels)),
            .init(name: F.sure, description: F.sureGuide, schema: DynamicGenerationSchema(type: Bool.self)),
            .init(name: F.gist, description: F.gistGuide, schema: DynamicGenerationSchema(type: String.self)),
        ])
        let schema = try GenerationSchema(root: root, dependencies: [])
        let response = try await session.respond(to: MailTriage.prompt(for: item), schema: schema,
                                                 options: GenerationOptions(samplingMode: .greedy))
        let content = response.content
        let level = try content.value(String.self, forProperty: F.level)
        let sure = (try? content.value(Bool.self, forProperty: F.sure)) ?? false
        let gist = (try? content.value(String.self, forProperty: F.gist)).flatMap(MailTriage.cleanGist)
        return Answer(classification: MailTriage.classification(level: level, sure: sure), gist: gist)
    }
    #endif

    private static func log(_ line: String) { Task { @MainActor in DiagnosticsLog.write(line) } }

    /// The operation's result, or nil if it didn't finish in time (it's cancelled).
    static func withTimeout<T: Sendable>(_ limit: Duration, _ op: @escaping @Sendable () async throws -> T) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await op() }
            group.addTask { try await Task.sleep(for: limit); return nil }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }
}
