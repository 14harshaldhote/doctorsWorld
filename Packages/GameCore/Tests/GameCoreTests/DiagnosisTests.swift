import Testing
@testable import GameCore

@Suite("Diagnosis reasoning")
struct DiagnosisTests {
    let catalog = ContentCatalog.standard

    /// A seated patient with the given condition.
    private func seated(_ conditionID: String) throws -> Shift {
        var shift = Shift.only(conditionID)
        try shift.seatFirst()
        return shift
    }

    @Test("On arrival the real condition is always among the candidates")
    func arrivalCandidates() {
        for condition in catalog.conditions {
            for seed in 1...20 {
                let shift = Shift.only(condition.id, config: .quiet(seed: UInt64(seed)))
                let ids = Diagnosis.candidates(for: shift.first, in: catalog).map { $0.id }
                #expect(ids.contains(condition.id))
            }
        }
    }

    @Test("After an exam, appendicitis still looks like food poisoning")
    func lookalikesAfterExam() throws {
        var shift = try seated("appendicitis")
        try shift.apply(.examine(patient: 1))
        let ids = Diagnosis.candidates(for: shift.first, in: catalog).map { $0.id }
        #expect(ids == ["appendicitis", "foodPoisoning"])
        let useful = Diagnosis.usefulTests(for: shift.first, in: catalog)
        #expect(useful == [.bloodTest, .scan])
    }

    @Test("A blood test tells appendicitis from food poisoning", arguments: ["appendicitis", "foodPoisoning"])
    func bloodTestSplits(conditionID: String) throws {
        var shift = try seated(conditionID)
        try shift.apply(.examine(patient: 1))
        try shift.apply(.runTest(patient: 1, test: .bloodTest))
        shift.advance(ticks: 150)
        #expect(Diagnosis.candidates(for: shift.first, in: catalog).map { $0.id } == [conditionID])
        #expect(Diagnosis.usefulTests(for: shift.first, in: catalog).isEmpty)
    }

    @Test("Some patients need no test once examined", arguments: ["deepCut", "concussion", "brokenArm"])
    func examEnough(conditionID: String) throws {
        var shift = try seated(conditionID)
        try shift.apply(.examine(patient: 1))
        #expect(Diagnosis.candidates(for: shift.first, in: catalog).map { $0.id } == [conditionID])
    }

    @Test("Tests already run or running are not suggested again")
    func noRepeatSuggestions() throws {
        var shift = try seated("appendicitis")
        try shift.apply(.examine(patient: 1))
        try shift.apply(.runTest(patient: 1, test: .bloodTest))
        #expect(Diagnosis.usefulTests(for: shift.first, in: catalog) == [.scan])
    }
}
