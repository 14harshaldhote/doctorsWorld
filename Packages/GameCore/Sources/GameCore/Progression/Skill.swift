/// The three skill branches.
public enum SkillBranch: String, Codable, CaseIterable, Sendable {
    /// Diagnosis: see more, learn faster.
    case eyes
    /// Procedures: steadier, more forgiving mini-games.
    case hands
    /// Shift control: slow things down.
    case calm
}

/// A skill bought with one skill point. Each changes how the game plays.
/// Within a branch, each skill needs the one before it.
public enum Skill: String, Codable, CaseIterable, Sendable {
    case keenEye, quickLabs, liarDetector
    case steadyHands, nervesOfSteel, secondChance
    case bedsideManner, timeDilation, goldenHour

    public var branch: SkillBranch {
        switch self {
        case .keenEye, .quickLabs, .liarDetector: .eyes
        case .steadyHands, .nervesOfSteel, .secondChance: .hands
        case .bedsideManner, .timeDilation, .goldenHour: .calm
        }
    }

    /// The skill that must be unlocked first, if any.
    public var prerequisite: Skill? {
        switch self {
        case .quickLabs: .keenEye
        case .liarDetector: .quickLabs
        case .nervesOfSteel: .steadyHands
        case .secondChance: .nervesOfSteel
        case .timeDilation: .bedsideManner
        case .goldenHour: .timeDilation
        case .keenEye, .steadyHands, .bedsideManner: nil
        }
    }

    public var title: String {
        switch self {
        case .keenEye: "Keen eye"
        case .quickLabs: "Quick labs"
        case .liarDetector: "Liar detector"
        case .steadyHands: "Steady hands"
        case .nervesOfSteel: "Nerves of steel"
        case .secondChance: "Second chance"
        case .bedsideManner: "Bedside manner"
        case .timeDilation: "Time dilation"
        case .goldenHour: "Golden hour"
        }
    }

    public var summary: String {
        switch self {
        case .keenEye: "Patients mention one extra symptom when they arrive."
        case .quickLabs: "Test results come back 25% faster."
        case .liarDetector: "Spot the patient who is leaving something out."
        case .steadyHands: "A wider perfect zone in procedures."
        case .nervesOfSteel: "Your hands stay steady late in the shift."
        case .secondChance: "One free retry of a procedure each shift."
        case .bedsideManner: "Patients in beds decline 15% slower."
        case .timeDilation: "Slow time for 5 seconds, once per shift."
        case .goldenHour: "Every patient declines 10% slower."
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// Why a skill could not be unlocked.
public enum SkillError: Error, Equatable, Sendable {
    case alreadyUnlocked
    case missingPrerequisite(Skill)
    case notEnoughPoints
}
