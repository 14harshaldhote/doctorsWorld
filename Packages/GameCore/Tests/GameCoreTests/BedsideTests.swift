import Testing
@testable import GameCore

@Suite("Bedside panel")
struct BedsideTests {
    private func bedside(_ shift: Shift, _ id: Int = 1) throws -> Bedside {
        try #require(Bedside(patientID: id, in: shift))
    }

    private func option(_ test: DiagnosticTest, in bedside: Bedside) throws -> Bedside.TestOption {
        try #require(bedside.tests.first { $0.test == test })
    }

    @Test("There is no panel for a patient who does not exist")
    func unknownPatient() {
        #expect(Bedside(patientID: 42, in: Shift(config: .quiet())) == nil)
    }

    @Test("A waiting patient can only be given a bed")
    func waitingPatient() throws {
        let panel = try bedside(Shift(config: .quiet()))
        #expect(!panel.canExamine)
        #expect(!panel.canDiagnose)
        #expect(!panel.canTreat)
        #expect(panel.tests.allSatisfy { $0.state == .blocked })
        #expect(panel.nextStep == .findBed)
        #expect(panel.knownVisible.count == 2)
    }

    @Test("Once in bed, examining comes first and every test is open")
    func inBed() throws {
        var shift = Shift(config: .quiet())
        try shift.seatFirst()
        let panel = try bedside(shift)
        #expect(panel.canExamine)
        #expect(panel.canDiagnose)
        #expect(panel.tests.count == DiagnosticTest.allCases.count)
        #expect(panel.tests.allSatisfy { $0.state == .available })
        #expect(panel.nextStep == .examine)
    }

    @Test("A running test shows its progress and blocks the others")
    func runningTest() throws {
        var shift = Shift.only("dehydration")
        try shift.seatFirst()
        try shift.apply(.examine(patient: 1))
        try shift.apply(.runTest(patient: 1, test: .bloodTest))
        shift.advance(ticks: 75)

        let panel = try bedside(shift)
        guard case .running(let left, let progress) = try option(.bloodTest, in: panel).state else {
            Issue.record("the blood test should be running")
            return
        }
        #expect(abs(left - 7.5) < 0.001)
        #expect(abs(progress - 0.5) < 0.001)
        #expect(try option(.xRay, in: panel).state == .blocked)
        #expect(panel.nextStep == .waitForTest(.bloodTest))
    }

    @Test("A finished test shows what it found, even when that is nothing")
    func finishedTests() throws {
        var shift = Shift.only("dehydration")
        try shift.seatFirst()
        try shift.apply(.runTest(patient: 1, test: .xRay))
        shift.advance(ticks: 100)
        try shift.apply(.runTest(patient: 1, test: .bloodTest))
        shift.advance(ticks: 150)

        let panel = try bedside(shift)
        #expect(try option(.xRay, in: panel).state == .done(found: []))
        #expect(try option(.bloodTest, in: panel).state == .done(found: [.dehydratedBlood]))
        #expect(try option(.scan, in: panel).state == .available)
        #expect(panel.knownFindings == [.dehydratedBlood])
    }

    @Test("The condition stays hidden until it is diagnosed")
    func hiddenUntilDiagnosed() throws {
        var shift = Shift.only("brokenArm")
        try shift.seatFirst()
        #expect(try bedside(shift).diagnosedCondition == nil)

        try shift.apply(.diagnose(patient: 1, condition: "brokenArm"))
        let panel = try bedside(shift)
        #expect(panel.diagnosedCondition?.id == "brokenArm")
        #expect(panel.canTreat)
        #expect(!panel.canDiagnose)
        #expect(panel.tests.allSatisfy { $0.state == .blocked })
        #expect(panel.nextStep == .treat(.splint))
    }

    @Test("Wrong guesses are listed once each, in order")
    func ruledOut() throws {
        var shift = Shift(config: .quiet(), catalog: ContentCatalog.standard.only("brokenArm", "dehydration", "concussion"))
        try shift.seatFirst()
        let others = ["brokenArm", "dehydration", "concussion"].filter { $0 != shift.first.conditionID }
        try shift.apply(.diagnose(patient: 1, condition: others[0]))
        try shift.apply(.diagnose(patient: 1, condition: others[0]))
        try shift.apply(.diagnose(patient: 1, condition: others[1]))
        #expect(try bedside(shift).ruledOut == others)
    }

    @Test("A patient who has left shows where they went")
    func gone() throws {
        var shift = Shift.only("deepCut")
        try shift.seatFirst()
        try shift.apply(.diagnose(patient: 1, condition: "deepCut"))
        try shift.apply(.treat(patient: 1, grade: .good))
        let panel = try bedside(shift)
        #expect(panel.nextStep == .gone(.discharged))
        #expect(!panel.canTreat)
        #expect(!panel.canExamine)
    }

    @Test("Quicker labs show shorter test times")
    func quickLabs() throws {
        var config = ShiftConfig.quiet()
        config.testDurationMultiplier = 0.75
        let panel = try bedside(Shift(config: config))
        #expect(try option(.bloodTest, in: panel).seconds == 11.25)
        #expect(try option(.breathingTest, in: panel).seconds == 3.75)
    }

    @Test("Everything is closed once the shift ends")
    func shiftOver() throws {
        var shift = Shift(config: .quiet(duration: 10))
        try shift.seatFirst()
        shift.advance(ticks: 100)
        let panel = try bedside(shift)
        #expect(!panel.canExamine && !panel.canDiagnose && !panel.canTreat)
        #expect(panel.nextStep == .gone(.handedOver))
    }
}
