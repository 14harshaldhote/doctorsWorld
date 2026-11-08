/// A test the player can order. Each one takes game time and can reveal
/// certain findings. A result that finds nothing is information too.
public enum DiagnosticTest: String, Codable, CaseIterable, Sendable {
    case bloodTest, xRay, scan, allergyPanel, breathingTest

    /// Game seconds the test takes before its result comes back.
    public var duration: Double {
        switch self {
        case .bloodTest: 15
        case .xRay: 10
        case .scan: 20
        case .allergyPanel: 12
        case .breathingTest: 5
        }
    }

    /// The findings this test can reveal.
    public var reveals: [Symptom] {
        switch self {
        case .bloodTest: [.dehydratedBlood, .highWhiteCells, .bacteriaInSample]
        case .xRay: [.brokenBone]
        case .scan: [.inflamedAppendix, .mildBrainInjury]
        case .allergyPanel: [.allergyMarkers]
        case .breathingTest: [.lungSpasm]
        }
    }

    public var displayName: String {
        switch self {
        case .xRay: "X-ray"
        default: readableName(rawValue)
        }
    }
}

/// How a patient is treated once diagnosed. Several become touch mini-games.
public enum Procedure: String, Codable, CaseIterable, Sendable {
    case suture, injection, ivDrip, splint, medication, surgery, cpr

    public var displayName: String {
        switch self {
        case .ivDrip: "IV drip"
        case .cpr: "CPR"
        default: readableName(rawValue)
        }
    }
}

/// How well a procedure went, graded by its mini-game.
public enum ProcedureGrade: String, Codable, CaseIterable, Sendable {
    case perfect, good, poor
}
