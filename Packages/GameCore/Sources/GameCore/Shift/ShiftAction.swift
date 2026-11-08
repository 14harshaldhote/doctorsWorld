/// Something the player does. The screen turns taps into these.
public enum ShiftAction: Codable, Sendable, Equatable {
    case assignBed(patient: Int, bed: Int)
    case examine(patient: Int)
    case runTest(patient: Int, test: DiagnosticTest)
    case diagnose(patient: Int, condition: String)
    case treat(patient: Int, grade: ProcedureGrade)
}

/// Why an action was refused. A refused action changes nothing.
public enum ShiftActionError: Error, Equatable, Sendable {
    case shiftOver
    case unknownPatient
    case unknownBed
    case unknownCondition
    case bedOccupied
    case patientNotWaiting
    case patientNotInBed
    case alreadyExamined
    case testAlreadyRunning
    case testAlreadyDone
    case alreadyDiagnosed
    case notDiagnosed
}

/// Why XP was awarded.
public enum XPReason: String, Codable, Sendable {
    case triage, diagnosis, treatment
}

/// Everything that happened in a shift, in order. The results screen and
/// the tests read this log.
public enum ShiftEvent: Codable, Sendable, Equatable {
    case arrived(patient: Int)
    case triaged(patient: Int, bed: Int, correct: Bool)
    case examined(patient: Int)
    case testStarted(patient: Int, test: DiagnosticTest)
    case testResult(patient: Int, test: DiagnosticTest, found: [Symptom])
    case diagnosed(patient: Int, condition: String, correct: Bool)
    case treated(patient: Int, grade: ProcedureGrade)
    case lost(patient: Int)
    case xp(amount: Int, reason: XPReason)
    case shiftEnded
}
