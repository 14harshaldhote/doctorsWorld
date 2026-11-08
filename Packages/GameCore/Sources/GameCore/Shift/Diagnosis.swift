/// Reasoning about which conditions still fit what the player knows.
public enum Diagnosis {
    /// Conditions consistent with everything known about the patient, in
    /// catalog order. The patient's real condition is always included.
    public static func candidates(for patient: Patient, in catalog: ContentCatalog) -> [Condition] {
        let knownVisible = Set(patient.knownSymptoms.filter { !$0.isFinding })
        return catalog.conditions.filter { condition in
            guard patient.knownSymptoms.isSubset(of: condition.allSymptoms) else { return false }
            if patient.examined && Set(condition.visible) != knownVisible { return false }
            for test in patient.testsRun {
                let expected = Set(condition.findings).intersection(test.reveals)
                let observed = patient.knownSymptoms.intersection(test.reveals)
                if expected != observed { return false }
            }
            return true
        }
    }

    /// Tests that would split the candidates apart, in a fixed order.
    /// Tests already run or running are left out.
    public static func usefulTests(for patient: Patient, in catalog: ContentCatalog) -> [DiagnosticTest] {
        let options = candidates(for: patient, in: catalog)
        guard options.count > 1 else { return [] }
        return DiagnosticTest.allCases.filter { test in
            guard !patient.testsRun.contains(test), patient.pendingTest?.test != test else { return false }
            let outcomes = Set(options.map { Set($0.findings).intersection(test.reveals) })
            return outcomes.count > 1
        }
    }
}
