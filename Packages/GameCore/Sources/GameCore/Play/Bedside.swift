/// Everything the bedside panel shows for one patient, and what the player
/// may do for them right now.
///
/// It is built only from what the player has a right to know: the real
/// condition stays hidden until it has been diagnosed.
public struct Bedside: Sendable, Equatable {
    /// Where one diagnostic test stands for this patient.
    public enum TestState: Sendable, Equatable {
        /// Can be ordered now.
        case available
        /// Ordered and running. `progress` goes from 0 to 1.
        case running(secondsLeft: Double, progress: Double)
        /// Result is back. An empty list means the test found nothing.
        case done(found: [Symptom])
        /// Cannot be ordered now (not in a bed, another test running, or
        /// already diagnosed).
        case blocked
    }

    /// One row of the test list.
    public struct TestOption: Sendable, Equatable, Identifiable {
        public let test: DiagnosticTest
        /// How long the test takes for this player, in game seconds.
        public let seconds: Double
        public let state: TestState
        public var id: DiagnosticTest { test }
    }

    /// The single most useful thing to do next, shown as a hint.
    public enum NextStep: Sendable, Equatable {
        case findBed
        case examine
        case waitForTest(DiagnosticTest)
        case testOrDiagnose
        case treat(Procedure)
        case gone(Patient.Location)
    }

    public let patient: Patient
    public let vitals: Vitals
    public let canExamine: Bool
    public let tests: [TestOption]
    public let canDiagnose: Bool
    /// Conditions the player already named wrongly for this patient.
    public let ruledOut: [String]
    /// Known only once the player has made the right diagnosis.
    public let diagnosedCondition: Condition?
    public let canTreat: Bool
    public let nextStep: NextStep

    /// The panel for a patient, or `nil` if there is no such patient.
    public init?(patientID: Int, in shift: Shift) {
        guard let patient = shift.patient(patientID) else { return nil }
        self.patient = patient
        vitals = shift.vitals(of: patient)

        let open = !shift.isOver && patient.bed != nil
        let undiagnosed = open && patient.diagnosis == nil
        canExamine = open && !patient.examined
        canDiagnose = undiagnosed
        canTreat = open && patient.diagnosis != nil
        diagnosedCondition = patient.diagnosis.flatMap { shift.catalog.condition($0) }
        ruledOut = Self.wrongGuesses(for: patientID, in: shift)
        tests = DiagnosticTest.allCases.map { test in
            let seconds = test.duration * shift.config.testDurationMultiplier
            return TestOption(
                test: test, seconds: seconds,
                state: Self.state(of: test, seconds: seconds, patient: patient, shift: shift, undiagnosed: undiagnosed)
            )
        }
        nextStep = Self.nextStep(for: patient, condition: diagnosedCondition)
    }

    /// Visible symptoms the patient has mentioned or shown so far.
    public var knownVisible: [Symptom] { patient.knownVisible }

    /// Findings the tests have turned up so far.
    public var knownFindings: [Symptom] { patient.knownFindings }

    private static func state(
        of test: DiagnosticTest, seconds: Double, patient: Patient, shift: Shift, undiagnosed: Bool
    ) -> TestState {
        if patient.testsRun.contains(test) {
            let condition = shift.condition(of: patient)
            let found = condition?.findings.filter { test.reveals.contains($0) } ?? []
            return .done(found: found.filter { patient.knownSymptoms.contains($0) })
        }
        if let pending = patient.pendingTest, pending.test == test {
            let left = max(0, Double(pending.readyAtTick - shift.tick) * Shift.step)
            let total = max(Shift.step, Double(Shift.ticks(for: seconds)) * Shift.step)
            return .running(secondsLeft: left, progress: min(1, max(0, 1 - left / total)))
        }
        guard undiagnosed, patient.pendingTest == nil else { return .blocked }
        return .available
    }

    private static func wrongGuesses(for patientID: Int, in shift: Shift) -> [String] {
        var seen: [String] = []
        for case let .diagnosed(id, condition, false) in shift.events where id == patientID {
            if !seen.contains(condition) { seen.append(condition) }
        }
        return seen
    }

    private static func nextStep(for patient: Patient, condition: Condition?) -> NextStep {
        switch patient.location {
        case .waiting: return .findBed
        case .discharged, .lost, .handedOver: return .gone(patient.location)
        case .bed: break
        }
        if let condition { return .treat(condition.procedure) }
        if !patient.examined { return .examine }
        if let pending = patient.pendingTest { return .waitForTest(pending.test) }
        return .testOrDiagnose
    }
}
