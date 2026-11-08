import Testing
@testable import GameCore

@Suite("Shift: time and arrivals")
struct ShiftTimeTests {
    @Test("A new shift starts with one patient waiting")
    func firstPatient() {
        let shift = Shift(config: ShiftConfig(seed: 1))
        #expect(shift.tick == 0)
        #expect(shift.patients.count == 1)
        #expect(shift.first.location == .waiting)
        #expect(shift.events == [.arrived(patient: 1)])
    }

    @Test("Patients mention two of their visible symptoms on arrival")
    func presentingSymptoms() throws {
        let shift = Shift.only("allergicReaction")
        let condition = try #require(shift.condition(of: shift.first))
        #expect(shift.first.knownSymptoms.count == 2)
        #expect(shift.first.knownSymptoms.isSubset(of: Set(condition.visible)))
    }

    @Test("Keen eye makes patients mention one more symptom")
    func extraSymptom() {
        var config = ShiftConfig.quiet()
        config.extraPresentingSymptoms = 1
        let shift = Shift(config: config, catalog: ContentCatalog.standard.only("allergicReaction"))
        #expect(shift.first.knownSymptoms.count == 3)
    }

    @Test("Arrivals follow the arrival interval")
    func arrivalTiming() {
        var shift = Shift(config: .every(10))
        shift.advance(ticks: 350)
        #expect(shift.patients.map { $0.arrivalTick } == [0, 100, 200, 300])
    }

    @Test("Nobody arrives once the shift is over")
    func noLateArrivals() {
        var shift = Shift(config: .every(10, duration: 30))
        shift.advance(ticks: 1_000)
        #expect(shift.patients.count == 3)
    }

    @Test("The shift ends on time and hands over everyone still there")
    func shiftEnds() throws {
        var shift = Shift(config: .every(10, duration: 30))
        try shift.seatFirst()
        shift.advance(ticks: 1_000)
        #expect(shift.isOver)
        #expect(shift.tick == 300)
        #expect(shift.remaining == 0)
        #expect(shift.patients.allSatisfy { $0.location == .handedOver })
        #expect(shift.beds.allSatisfy { $0 == nil })
        #expect(shift.events.last == .shiftEnded)
    }

    @Test("Time does not move after the shift ends")
    func frozenAfterEnd() {
        var shift = Shift(config: .quiet(duration: 10))
        shift.advance(ticks: 500)
        let finished = shift
        shift.advance(ticks: 500)
        #expect(shift == finished)
    }

    @Test("Elapsed and remaining time add up to the shift length")
    func clockReadings() {
        var shift = Shift(config: .quiet(duration: 60))
        shift.advance(ticks: 125)
        #expect(abs(shift.elapsed - 12.5) < 1e-9)
        #expect(abs(shift.remaining - 47.5) < 1e-9)
    }

    @Test("The same seed always brings the same patients")
    func sameSeedSamePatients() {
        var first = Shift(config: ShiftConfig(seed: 7))
        var second = Shift(config: ShiftConfig(seed: 7))
        first.advance(ticks: 3_000)
        second.advance(ticks: 3_000)
        #expect(first.patients == second.patients)
        #expect(first == second)
    }

    @Test("A different seed brings different patients")
    func differentSeedDifferentPatients() {
        var first = Shift(config: ShiftConfig(seed: 7))
        var second = Shift(config: ShiftConfig(seed: 8))
        first.advance(ticks: 3_000)
        second.advance(ticks: 3_000)
        #expect(first.patients.map { $0.name } != second.patients.map { $0.name })
    }

    @Test("The monitor reflects the patient's condition")
    func monitor() {
        let shift = Shift.only("asthmaAttack")
        let vitals = shift.vitals(of: shift.first)
        #expect(vitals.heartRate > Vitals.healthy.heartRate)
        #expect(vitals.oxygen < Vitals.healthy.oxygen)
    }
}

@Suite("Shift: decline")
struct ShiftDeclineTests {
    @Test("Waiting patients decline fastest, diagnosed patients slowest")
    func declineRates() throws {
        var waiting = Shift.only("appendicitis")
        var inBed = waiting
        var diagnosed = waiting
        try inBed.seatFirst()
        try diagnosed.seatFirst()
        try diagnosed.apply(.diagnose(patient: 1, condition: "appendicitis"))
        waiting.advance(ticks: 100)
        inBed.advance(ticks: 100)
        diagnosed.advance(ticks: 100)
        #expect(waiting.first.stability < inBed.first.stability)
        #expect(inBed.first.stability < diagnosed.first.stability)
    }

    @Test("A severe patient left waiting is lost before the shift ends")
    func neglectedPatientIsLost() {
        var shift = Shift.only("appendicitis")
        shift.advance(ticks: 2_400)
        #expect(shift.first.location == .lost)
        #expect(shift.events.contains(.lost(patient: 1)))
        #expect(shift.report.lost == 1)
    }

    @Test("Losing a patient frees their bed")
    func lostPatientFreesBed() throws {
        var config = ShiftConfig.quiet()
        config.declineMultiplier = 10
        var shift = Shift(config: config, catalog: ContentCatalog.standard.only("appendicitis"))
        try shift.seatFirst()
        shift.advance(ticks: 600)
        #expect(shift.first.location == .lost)
        #expect(shift.beds[0] == nil)
    }

    @Test("Stability never drops below zero")
    func neverNegative() {
        var shift = Shift(config: .every(5))
        shift.advance(ticks: 3_000)
        #expect(shift.patients.allSatisfy { (0...100).contains($0.stability) })
    }
}
