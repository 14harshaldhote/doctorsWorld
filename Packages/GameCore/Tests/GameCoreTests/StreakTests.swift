import Testing
@testable import GameCore

@Suite("Shift: streaks")
struct StreakTests {
    /// Seats the next waiting patient, diagnoses and treats them.
    private func treatNext(_ shift: inout Shift, grade: ProcedureGrade = .good, wrongFirst: Bool = false) throws {
        shift.advance(ticks: 10)
        let patient = try #require(shift.waitingPatients.first)
        try shift.apply(.assignBed(patient: patient.id, bed: 0))
        if wrongFirst {
            let other = try #require(shift.catalog.conditions.first { $0.id != patient.conditionID })
            try shift.apply(.diagnose(patient: patient.id, condition: other.id))
        }
        try shift.apply(.diagnose(patient: patient.id, condition: patient.conditionID))
        try shift.apply(.treat(patient: patient.id, grade: grade))
    }

    private func newShift() -> Shift {
        Shift(config: .every(1), catalog: ContentCatalog.standard.only("deepCut", "dehydration"))
    }

    @Test("The streak bonus grows 10% per clean patient and stops at 50%")
    func bonusGrowsAndCaps() throws {
        var shift = newShift()
        for _ in 0..<7 { try treatNext(&shift) }
        #expect(shift.xpAwarded(for: .treatment) == [25, 28, 30, 33, 35, 38, 38])
        #expect(shift.streak == 7)
        #expect(shift.bestStreak == 7)
    }

    @Test("A poor procedure still gets the bonus but ends the streak")
    func poorEndsStreak() throws {
        var shift = newShift()
        try treatNext(&shift)
        try treatNext(&shift)
        try treatNext(&shift, grade: .poor)
        try treatNext(&shift)
        #expect(shift.xpAwarded(for: .treatment) == [25, 28, 18, 25])
        #expect(shift.bestStreak == 2)
    }

    @Test("A wrong guess ends the streak")
    func wrongGuessEndsStreak() throws {
        var shift = newShift()
        try treatNext(&shift)
        try treatNext(&shift)
        try treatNext(&shift, wrongFirst: true)
        try treatNext(&shift)
        #expect(shift.xpAwarded(for: .treatment) == [25, 28, 25, 25])
        #expect(shift.streak == 1)
    }

    @Test("Losing a patient ends the streak")
    func lossEndsStreak() throws {
        var shift = newShift()
        try treatNext(&shift)
        try treatNext(&shift)
        shift.advance(ticks: 10)
        let doomed = try #require(shift.patients.firstIndex { $0.location == .waiting })
        shift.patients[doomed].stability = 0.001
        shift.advance(ticks: 1)
        #expect(shift.patients[doomed].location == .lost)
        #expect(shift.streak == 0)
    }
}
