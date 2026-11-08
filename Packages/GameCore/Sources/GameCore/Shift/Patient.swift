/// One person in the hospital during a shift.
public struct Patient: Codable, Sendable, Equatable, Identifiable {
    /// Where the patient is right now.
    public enum Location: Codable, Sendable, Equatable {
        case waiting
        case bed(Int)
        case discharged
        case lost
        /// Still in the hospital when the shift ended; the next team takes over.
        case handedOver
    }

    public let id: Int
    public let name: String
    /// The real condition. The player never sees this directly.
    public let conditionID: String
    public let arrivalTick: Int
    /// 0 (crashed) to 100 (healthy). Falls every second until treated.
    public internal(set) var stability: Double
    public internal(set) var location: Location = .waiting
    /// Everything the player has learned so far, visible and found.
    public internal(set) var knownSymptoms: Set<Symptom>
    public internal(set) var examined = false
    /// Tests whose results are back, in the order they finished.
    public internal(set) var testsRun: [DiagnosticTest] = []
    public internal(set) var pendingTest: PendingTest?
    /// Set once the player names the right condition.
    public internal(set) var diagnosis: String?
    public internal(set) var wrongGuesses = 0
    public internal(set) var grade: ProcedureGrade?

    init(id: Int, name: String, conditionID: String, arrivalTick: Int, stability: Double, knownSymptoms: Set<Symptom>) {
        self.id = id
        self.name = name
        self.conditionID = conditionID
        self.arrivalTick = arrivalTick
        self.stability = stability
        self.knownSymptoms = knownSymptoms
    }

    /// Waiting or in a bed: still the player's responsibility.
    public var isActive: Bool {
        switch location {
        case .waiting, .bed: true
        case .discharged, .lost, .handedOver: false
        }
    }

    /// The bed this patient is in, if any.
    public var bed: Int? {
        if case .bed(let number) = location { return number }
        return nil
    }

    public var status: PatientStatus { PatientStatus(stability: stability) }

    /// Known visible symptoms, sorted for display.
    public var knownVisible: [Symptom] { knownSymptoms.filter { !$0.isFinding }.sorted() }

    /// Known findings, sorted for display.
    public var knownFindings: [Symptom] { knownSymptoms.filter(\.isFinding).sorted() }
}

/// A test that has been ordered and is waiting for its result.
public struct PendingTest: Codable, Sendable, Equatable {
    public let test: DiagnosticTest
    public let readyAtTick: Int
}
