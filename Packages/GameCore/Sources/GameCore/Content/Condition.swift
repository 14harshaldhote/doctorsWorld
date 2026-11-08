/// An illness or injury a patient can arrive with.
public struct Condition: Codable, Sendable, Equatable, Identifiable {
    /// How serious a condition is: sets starting stability and how fast it falls.
    public enum Severity: String, Codable, CaseIterable, Sendable {
        case minor, moderate, severe

        /// Stability (0 to 100) a patient arrives with, before a small random shift.
        public var startStability: Double {
            switch self {
            case .minor: 85
            case .moderate: 75
            case .severe: 65
            }
        }

        /// Stability lost per game second while waiting untreated.
        public var declinePerSecond: Double {
            switch self {
            case .minor: 0.08
            case .moderate: 0.15
            case .severe: 0.3
            }
        }
    }

    public let id: String
    public let name: String
    public let severity: Severity
    /// Symptoms that can be seen on arrival or by examining the patient.
    public let visible: [Symptom]
    /// Symptoms that only diagnostic tests reveal.
    public let findings: [Symptom]
    public let procedure: Procedure
    /// Relative chance of this condition walking in.
    public let weight: Double
    /// How the monitor reacts as this patient gets worse.
    public let vitals: VitalsProfile

    public init(
        id: String,
        name: String,
        severity: Severity,
        visible: [Symptom],
        findings: [Symptom],
        procedure: Procedure,
        weight: Double = 1,
        vitals: VitalsProfile = .standard
    ) {
        self.id = id
        self.name = name
        self.severity = severity
        self.visible = visible
        self.findings = findings
        self.procedure = procedure
        self.weight = weight
        self.vitals = vitals
    }

    /// Every symptom this condition can show, visible and found.
    public var allSymptoms: Set<Symptom> { Set(visible).union(findings) }
}
