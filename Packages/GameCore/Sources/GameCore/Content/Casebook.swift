/// One page of the doctor's casebook: what a condition looks like from the
/// outside and which tests can confirm it. It never lists hidden findings,
/// so reading it is fair game during a shift.
public struct CasebookEntry: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let severity: Condition.Severity
    /// Every visible symptom of the condition, sorted.
    public let symptoms: [Symptom]
    /// Tests that turn up at least one of its findings, in test order.
    /// Empty when the visible symptoms alone are enough.
    public let confirmingTests: [DiagnosticTest]
    public let procedure: Procedure
}

extension ContentCatalog {
    /// The casebook, one entry per condition, in catalog order.
    public var casebook: [CasebookEntry] {
        conditions.map { condition in
            CasebookEntry(
                id: condition.id,
                name: condition.name,
                severity: condition.severity,
                symptoms: condition.visible.sorted(),
                confirmingTests: DiagnosticTest.allCases.filter { test in
                    condition.findings.contains { test.reveals.contains($0) }
                },
                procedure: condition.procedure
            )
        }
    }
}
