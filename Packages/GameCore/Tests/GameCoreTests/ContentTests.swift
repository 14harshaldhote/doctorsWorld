import Foundation
import Testing
@testable import GameCore

@Suite("Content")
struct ContentTests {
    let catalog = ContentCatalog.standard

    @Test("The standard catalog has the eight first-release conditions")
    func eightConditions() {
        let ids = catalog.conditions.map { $0.id }
        #expect(ids == [
            "dehydration", "brokenArm", "allergicReaction", "asthmaAttack",
            "appendicitis", "foodPoisoning", "concussion", "deepCut"
        ])
    }

    @Test("The standard catalog passes validation")
    func standardIsValid() {
        #expect(catalog.validate().isEmpty)
    }

    @Test("Conditions can be looked up by id")
    func lookup() {
        #expect(catalog.condition("deepCut")?.procedure == .suture)
        #expect(catalog.condition("nope") == nil)
    }

    @Test("only() keeps the requested conditions in the requested order")
    func onlyFilter() {
        #expect(catalog.only("deepCut", "dehydration", "missing").conditions.map { $0.id } == ["deepCut", "dehydration"])
    }

    @Test("Visible symptoms overlap between conditions on purpose")
    func overlaps() {
        var counts: [Symptom: Int] = [:]
        for condition in catalog.conditions {
            for symptom in condition.visible { counts[symptom, default: 0] += 1 }
        }
        #expect(counts.filter { $0.value > 1 }.count >= 3)
    }

    @Test("Appendicitis and food poisoning look the same until tested")
    func lookalikes() throws {
        let appendix = try #require(catalog.condition("appendicitis"))
        let food = try #require(catalog.condition("foodPoisoning"))
        #expect(Set(appendix.visible) == Set(food.visible))
        #expect(Set(appendix.findings) != Set(food.findings))
    }

    @Test("Every test takes 5 to 20 seconds and reveals only findings")
    func testsAreSane() {
        for test in DiagnosticTest.allCases {
            #expect((5...20).contains(test.duration))
            #expect(!test.reveals.isEmpty)
            #expect(test.reveals.allSatisfy { $0.isFinding })
        }
    }

    @Test("Every finding can be revealed by some test")
    func findingsRevealable() {
        for finding in Symptom.findings {
            #expect(DiagnosticTest.allCases.contains { $0.reveals.contains(finding) })
        }
    }

    @Test("Validation catches a duplicate id")
    func duplicateID() throws {
        let deepCut = try #require(catalog.condition("deepCut"))
        #expect(ContentCatalog(conditions: [deepCut, deepCut]).validate().contains(.duplicateID("deepCut")))
    }

    @Test("Validation catches conditions nobody could tell apart")
    func indistinguishable() throws {
        let deepCut = try #require(catalog.condition("deepCut"))
        let twin = Condition(
            id: "twin", name: "Twin", severity: .minor,
            visible: [.deepWound, .bleeding], findings: [], procedure: .suture
        )
        #expect(ContentCatalog(conditions: [deepCut, twin]).validate().contains(.indistinguishable("deepCut", "twin")))
    }

    @Test("Validation catches symptoms in the wrong list")
    func wrongLists() {
        let odd = Condition(
            id: "odd", name: "Odd", severity: .minor,
            visible: [.brokenBone], findings: [.fever], procedure: .splint
        )
        let issues = ContentCatalog(conditions: [odd]).validate()
        #expect(issues.contains(.findingShownAsVisible(condition: "odd", symptom: .brokenBone)))
        #expect(issues.contains(.visibleListedAsFinding(condition: "odd", symptom: .fever)))
    }

    @Test("Validation catches empty catalogs, missing symptoms and bad weights")
    func emptyAndWeights() {
        #expect(ContentCatalog(conditions: []).validate() == [.noConditions])
        let blank = Condition(
            id: "blank", name: "Blank", severity: .minor,
            visible: [], findings: [], procedure: .medication, weight: 0
        )
        let issues = ContentCatalog(conditions: [blank]).validate()
        #expect(issues.contains(.noVisibleSymptoms("blank")))
        #expect(issues.contains(.badWeight("blank")))
    }

    @Test("The catalog survives a JSON round trip")
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(catalog)
        #expect(try JSONDecoder().decode(ContentCatalog.self, from: data) == catalog)
    }

    @Test("Names read naturally")
    func displayNames() {
        #expect(Symptom.shortnessOfBreath.displayName == "Shortness of breath")
        #expect(DiagnosticTest.xRay.displayName == "X-ray")
        #expect(DiagnosticTest.bloodTest.displayName == "Blood test")
        #expect(Procedure.ivDrip.displayName == "IV drip")
        #expect(Procedure.cpr.displayName == "CPR")
    }
}

@Suite("Vitals")
struct VitalsTests {
    @Test("A fully stable patient shows healthy numbers")
    func healthy() {
        #expect(Vitals(stability: 100, profile: .standard) == .healthy)
    }

    @Test("Lower stability raises heart rate and lowers oxygen and pressure")
    func worsening() {
        let better = Vitals(stability: 80, profile: .standard)
        let worse = Vitals(stability: 30, profile: .standard)
        #expect(worse.heartRate > better.heartRate)
        #expect(worse.oxygen < better.oxygen)
        #expect(worse.systolic < better.systolic)
    }

    @Test("Stability outside 0 to 100 is clamped")
    func clamped() {
        #expect(Vitals(stability: 150, profile: .standard) == .healthy)
        #expect(Vitals(stability: -20, profile: .standard) == Vitals(stability: 0, profile: .standard))
    }

    @Test(
        "Status follows stability",
        arguments: zip(
            [100.0, 60, 59.9, 30, 29.9, 0.1, 0, -5],
            [PatientStatus.stable, .stable, .serious, .serious, .critical, .critical, .crashed, .crashed]
        )
    )
    func status(stability: Double, expected: PatientStatus) {
        #expect(PatientStatus(stability: stability) == expected)
    }

    @Test("Statuses are ordered from best to worst")
    func statusOrder() {
        #expect(PatientStatus.stable < .serious)
        #expect(PatientStatus.serious < .critical)
        #expect(PatientStatus.critical < .crashed)
    }

    @Test("Monitor values stay believable even at zero stability")
    func believable() {
        for condition in ContentCatalog.standard.conditions {
            let vitals = Vitals(stability: 0, profile: condition.vitals)
            #expect(vitals.heartRate < 200)
            #expect(vitals.oxygen > 70)
            #expect(vitals.systolic > 60)
        }
    }
}
