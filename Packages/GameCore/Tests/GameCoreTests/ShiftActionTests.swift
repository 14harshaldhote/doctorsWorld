import Testing
@testable import GameCore

@Suite("Shift: triage")
struct TriageTests {
    @Test("Assigning a bed moves the patient into it")
    func assignBed() throws {
        var shift = Shift(config: .quiet())
        try shift.apply(.assignBed(patient: 1, bed: 2))
        #expect(shift.first.location == .bed(2))
        #expect(shift.beds == [nil, nil, 1])
        #expect(shift.freeBeds == [0, 1])
    }

    @Test("Bad bed assignments are refused and change nothing")
    func refusedAssignments() throws {
        var shift = Shift(config: .every(1))
        shift.advance(ticks: 10)
        try shift.apply(.assignBed(patient: 1, bed: 0))
        let before = shift
        #expect(throws: ShiftActionError.bedOccupied) { try shift.apply(.assignBed(patient: 2, bed: 0)) }
        #expect(throws: ShiftActionError.unknownBed) { try shift.apply(.assignBed(patient: 2, bed: 9)) }
        #expect(throws: ShiftActionError.unknownPatient) { try shift.apply(.assignBed(patient: 99, bed: 1)) }
        #expect(throws: ShiftActionError.patientNotWaiting) { try shift.apply(.assignBed(patient: 1, bed: 1)) }
        #expect(shift == before)
    }

    @Test("Seating the most urgent patient first earns triage XP")
    func correctTriage() throws {
        var shift = Shift.only("appendicitis", config: .every(1))
        shift.advance(ticks: 10)
        let urgent = try #require(shift.waitingPatients.min { $0.stability < $1.stability })
        try shift.apply(.assignBed(patient: urgent.id, bed: 0))
        #expect(shift.events.contains(.triaged(patient: urgent.id, bed: 0, correct: true)))
        #expect(shift.xpAwarded(for: .triage) == [5])
    }

    @Test("Seating a less urgent patient first earns nothing")
    func wrongTriage() throws {
        var shift = Shift.only("appendicitis", config: .every(1))
        shift.advance(ticks: 10)
        let calmer = try #require(shift.waitingPatients.max { $0.stability < $1.stability })
        try shift.apply(.assignBed(patient: calmer.id, bed: 0))
        #expect(shift.events.contains(.triaged(patient: calmer.id, bed: 0, correct: false)))
        #expect(shift.xpAwarded(for: .triage).isEmpty)
    }
}

@Suite("Shift: examining and testing")
struct ExamineAndTestTests {
    @Test("Examining reveals every visible symptom")
    func examineRevealsVisible() throws {
        var shift = Shift.only("concussion")
        try shift.seatFirst()
        try shift.apply(.examine(patient: 1))
        #expect(shift.first.examined)
        #expect(shift.first.knownVisible == [.confusion, .dizziness, .headache])
        #expect(shift.first.knownFindings.isEmpty)
    }

    @Test("Examining needs a bed and only works once")
    func examineRules() throws {
        var shift = Shift.only("concussion")
        #expect(throws: ShiftActionError.patientNotInBed) { try shift.apply(.examine(patient: 1)) }
        try shift.seatFirst()
        try shift.apply(.examine(patient: 1))
        #expect(throws: ShiftActionError.alreadyExamined) { try shift.apply(.examine(patient: 1)) }
    }

    @Test("A test result arrives exactly when the test finishes")
    func testTiming() throws {
        var shift = Shift.only("appendicitis")
        try shift.seatFirst()
        try shift.apply(.runTest(patient: 1, test: .bloodTest))
        shift.advance(ticks: 149)
        #expect(shift.first.pendingTest != nil)
        #expect(shift.first.knownFindings.isEmpty)
        shift.advance(ticks: 1)
        #expect(shift.first.pendingTest == nil)
        #expect(shift.first.testsRun == [.bloodTest])
        #expect(shift.first.knownFindings == [.highWhiteCells])
        #expect(shift.events.contains(.testResult(patient: 1, test: .bloodTest, found: [.highWhiteCells])))
    }

    @Test("A test can come back empty")
    func negativeResult() throws {
        var shift = Shift.only("appendicitis")
        try shift.seatFirst()
        try shift.apply(.runTest(patient: 1, test: .xRay))
        shift.advance(ticks: 100)
        #expect(shift.events.contains(.testResult(patient: 1, test: .xRay, found: [])))
        #expect(shift.first.testsRun == [.xRay])
    }

    @Test("One test at a time, and never the same test twice")
    func testRules() throws {
        var shift = Shift.only("appendicitis")
        #expect(throws: ShiftActionError.patientNotInBed) { try shift.apply(.runTest(patient: 1, test: .scan)) }
        try shift.seatFirst()
        try shift.apply(.runTest(patient: 1, test: .breathingTest))
        #expect(throws: ShiftActionError.testAlreadyRunning) { try shift.apply(.runTest(patient: 1, test: .scan)) }
        shift.advance(ticks: 50)
        #expect(throws: ShiftActionError.testAlreadyDone) { try shift.apply(.runTest(patient: 1, test: .breathingTest)) }
    }

    @Test("Quicker labs shorten every test")
    func quickerLabs() throws {
        var config = ShiftConfig.quiet()
        config.testDurationMultiplier = 0.5
        var shift = Shift(config: config, catalog: ContentCatalog.standard.only("appendicitis"))
        try shift.seatFirst()
        try shift.apply(.runTest(patient: 1, test: .scan))
        shift.advance(ticks: 100)
        #expect(shift.first.testsRun == [.scan])
    }
}

@Suite("Shift: diagnosis and treatment")
struct DiagnoseAndTreatTests {
    @Test("A correct diagnosis is recorded and earns XP")
    func correctDiagnosis() throws {
        var shift = Shift.only("deepCut")
        try shift.seatFirst()
        try shift.apply(.diagnose(patient: 1, condition: "deepCut"))
        #expect(shift.first.diagnosis == "deepCut")
        #expect(shift.xpAwarded(for: .diagnosis) == [20])
        #expect(throws: ShiftActionError.alreadyDiagnosed) { try shift.apply(.diagnose(patient: 1, condition: "deepCut")) }
        #expect(throws: ShiftActionError.alreadyDiagnosed) { try shift.apply(.runTest(patient: 1, test: .scan)) }
    }

    @Test("Needing two or more tests halves the diagnosis XP")
    func manyTests() throws {
        var shift = Shift.only("appendicitis")
        try shift.seatFirst()
        try shift.apply(.runTest(patient: 1, test: .bloodTest))
        shift.advance(ticks: 150)
        try shift.apply(.runTest(patient: 1, test: .scan))
        shift.advance(ticks: 200)
        try shift.apply(.diagnose(patient: 1, condition: "appendicitis"))
        #expect(shift.xpAwarded(for: .diagnosis) == [10])
    }

    @Test("A wrong diagnosis costs the patient stability and earns nothing")
    func wrongDiagnosis() throws {
        var shift = Shift(config: .quiet(), catalog: ContentCatalog.standard.only("appendicitis", "foodPoisoning"))
        try shift.seatFirst()
        let wrong = shift.first.conditionID == "appendicitis" ? "foodPoisoning" : "appendicitis"
        let before = shift.first.stability
        try shift.apply(.diagnose(patient: 1, condition: wrong))
        #expect(shift.first.diagnosis == nil)
        #expect(shift.first.wrongGuesses == 1)
        #expect(abs(shift.first.stability - (before - 10)) < 1e-9)
        #expect(shift.events.contains(.diagnosed(patient: 1, condition: wrong, correct: false)))
        #expect(shift.xpAwarded(for: .diagnosis).isEmpty)
    }

    @Test("A wrong diagnosis can be the last straw")
    func wrongDiagnosisCanKill() throws {
        var shift = Shift(config: .quiet(), catalog: ContentCatalog.standard.only("appendicitis", "foodPoisoning"))
        try shift.seatFirst()
        shift.patients[0].stability = 5
        let wrong = shift.first.conditionID == "appendicitis" ? "foodPoisoning" : "appendicitis"
        try shift.apply(.diagnose(patient: 1, condition: wrong))
        #expect(shift.first.location == .lost)
        #expect(shift.beds[0] == nil)
    }

    @Test("Diagnosing a condition that does not exist is refused")
    func unknownCondition() throws {
        var shift = Shift.only("deepCut")
        try shift.seatFirst()
        #expect(throws: ShiftActionError.unknownCondition) { try shift.apply(.diagnose(patient: 1, condition: "zombie")) }
    }

    @Test("Treatment needs a diagnosis first")
    func treatNeedsDiagnosis() throws {
        var shift = Shift.only("deepCut")
        try shift.seatFirst()
        #expect(throws: ShiftActionError.notDiagnosed) { try shift.apply(.treat(patient: 1, grade: .good)) }
    }

    @Test("Treatment sends the patient home and pays by grade", arguments: zip(ProcedureGrade.allCases, [40, 25, 15]))
    func treatment(grade: ProcedureGrade, expectedXP: Int) throws {
        var shift = Shift.only("deepCut")
        try shift.seatFirst()
        try shift.apply(.diagnose(patient: 1, condition: "deepCut"))
        try shift.apply(.treat(patient: 1, grade: grade))
        #expect(shift.first.location == .discharged)
        #expect(shift.first.grade == grade)
        #expect(shift.beds[0] == nil)
        #expect(shift.xpAwarded(for: .treatment) == [expectedXP])
    }

    @Test("Nothing can be done after the shift ends")
    func noActionsAfterEnd() {
        var shift = Shift(config: .quiet(duration: 5))
        shift.advance(ticks: 100)
        #expect(throws: ShiftActionError.shiftOver) { try shift.apply(.assignBed(patient: 1, bed: 0)) }
    }
}
