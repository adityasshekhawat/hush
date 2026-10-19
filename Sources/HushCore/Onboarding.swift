import Foundation

/// "What do you mostly do on your Mac?" (docs/personas.md, docs/onboarding-plan.md). Pick any.
public enum Persona: String, Sendable, Codable, CaseIterable {
    case builder      // I build software          (the Conductor)
    case aiBuilder    // I build with AI           (the Maker)
    case juggler      // I manage work and messages (the Juggler)
    case company      // I just want company       (the Solo / Collector)

    public var title: String {
        switch self {
        case .builder: "I build software"
        case .aiBuilder: "I build with AI"
        case .juggler: "I manage work and messages"
        case .company: "I just want company"
        }
    }

    public var subtitle: String {
        switch self {
        case .builder: "Watch my Claude Code runs, answer code questions"
        case .aiBuilder: "Tell me when my agent's done, explain changes plainly"
        case .juggler: "Meetings and messages, only when they matter"
        case .company: "A small friend on my desk"
        }
    }

    public var symbol: String {
        switch self {
        case .builder: "chevron.left.forwardslash.chevron.right"
        case .aiBuilder: "wand.and.stars"
        case .juggler: "tray.full"
        case .company: "heart"
        }
    }
}

/// Things onboarding can offer to connect, in the order they're offered.
public enum ConnectStep: String, Sendable, Codable, CaseIterable {
    case calendar      // meeting reminders
    case claudeCode    // watch Claude Code sessions (hooks)
    case askHotkey     // try ⌘⇧H
}

/// What the picked personas switch on. Everything stays editable afterwards.
public struct OnboardingPreset: Sendable, Equatable {
    public var connect: [ConnectStep]
    public var perch: Bool
    public var moods: Bool
    public var maxInterruptsPerDay: Int

    /// `claudeInstalled`: only offer the Claude Code step when there's something to watch.
    public static func from(_ personas: Set<Persona>, claudeInstalled: Bool) -> OnboardingPreset {
        let builds = personas.contains(.builder) || personas.contains(.aiBuilder)
        var connect: [ConnectStep] = []
        // Calendar helps everyone except someone who only wants company (offered last for them, below).
        if personas.isEmpty || personas.contains(.juggler) || builds { connect.append(.calendar) }
        if builds && claudeInstalled { connect.append(.claudeCode) }
        connect.append(.askHotkey)
        if personas == [.company] { connect = [.askHotkey, .calendar] }
        return OnboardingPreset(
            connect: connect,
            perch: personas.contains(.company) || builds || personas.isEmpty,
            moods: false,                                             // opt-in only (moods can feel naggy)
            maxInterruptsPerDay: personas.contains(.juggler) ? 5 : (personas == [.company] ? 3 : 5))
    }
}

public enum OnboardingStep: Int, Sendable, Codable, CaseIterable, Comparable {
    case arrival, look, question, sayHi, connect, quiet, goodbye
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// One-time explanations the first time something happens (first week only).
public enum FirstTip: String, Sendable, Codable, CaseIterable {
    case meetingClock, envelope, typingDuck, agentDone, tuckIn

    public var text: String {
        switch self {
        case .meetingClock: "I'm holding the clock: a meeting starts in about 10 minutes. At 2 minutes I'll come closer."
        case .envelope: "Something's worth a look. Click me to see it, or right-click to say “not now”."
        case .typingDuck: "I duck down while you type, so I'm never in the way."
        case .agentDone: "Your Claude Code run finished while you were elsewhere. Click me for details."
        case .tuckIn: "Every evening I tuck in and tell you what I held back."
        }
    }
}

/// Saved onboarding state (UserDefaults as JSON). Pure, so the rules are testable.
public struct OnboardingProgress: Sendable, Codable, Equatable {
    public var firstLaunch: Date
    public var finished: Bool = false
    public var skipped: Bool = false
    public var lastStep: OnboardingStep = .arrival
    public var personas: Set<Persona> = []
    public var sayHi: Set<String> = []                  // "hover", "pat", "drag"
    public var connected: Set<ConnectStep> = []
    public var declined: Set<ConnectStep> = []
    public var tipsShown: Set<FirstTip> = []
    public var tipsOff: Bool = false

    public init(firstLaunch: Date) { self.firstLaunch = firstLaunch }

    /// Run the journey on launch?
    public var shouldStart: Bool { !finished && !skipped }

    /// Show a first-week tip for this moment?
    public func shouldShow(_ tip: FirstTip, now: Date) -> Bool {
        finished && !tipsOff && !tipsShown.contains(tip) && now.timeIntervalSince(firstLaunch) < 7 * 86_400
    }

    /// What's left for the setup checklist.
    public func remaining(claudeInstalled: Bool) -> [ConnectStep] {
        ConnectStep.allCases.filter { step in
            !connected.contains(step) && !(step == .claudeCode && !claudeInstalled)
        }
    }
}
