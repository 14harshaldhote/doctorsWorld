/// Everything that can walk through the hospital doors.
public struct ContentCatalog: Codable, Sendable, Equatable {
    public var conditions: [Condition]

    public init(conditions: [Condition]) {
        self.conditions = conditions
    }

    /// The condition with this id, if any.
    public func condition(_ id: String) -> Condition? {
        conditions.first { $0.id == id }
    }

    /// A catalog holding only the given conditions, in the given order.
    /// Handy for tests and for focused tutorial shifts.
    public func only(_ ids: String...) -> ContentCatalog {
        ContentCatalog(conditions: ids.compactMap { condition($0) })
    }

    /// Problems that would make a patient unsolvable or the game unfair.
    /// The standard catalog must always return an empty list.
    public func validate() -> [ContentIssue] {
        var issues: [ContentIssue] = []
        if conditions.isEmpty { issues.append(.noConditions) }
        var seen = Set<String>()
        for condition in conditions {
            if !seen.insert(condition.id).inserted { issues.append(.duplicateID(condition.id)) }
            if condition.visible.isEmpty { issues.append(.noVisibleSymptoms(condition.id)) }
            if condition.weight <= 0 { issues.append(.badWeight(condition.id)) }
            for symptom in condition.visible where symptom.isFinding {
                issues.append(.findingShownAsVisible(condition: condition.id, symptom: symptom))
            }
            for symptom in condition.findings where !symptom.isFinding {
                issues.append(.visibleListedAsFinding(condition: condition.id, symptom: symptom))
            }
            for symptom in condition.findings where symptom.isFinding && !Self.isRevealable(symptom) {
                issues.append(.unrevealableFinding(condition: condition.id, symptom: symptom))
            }
        }
        for (index, first) in conditions.enumerated() {
            for second in conditions[(index + 1)...]
            where Set(first.visible) == Set(second.visible) && Set(first.findings) == Set(second.findings) {
                issues.append(.indistinguishable(first.id, second.id))
            }
        }
        return issues
    }

    private static func isRevealable(_ symptom: Symptom) -> Bool {
        DiagnosticTest.allCases.contains { $0.reveals.contains(symptom) }
    }
}

/// A problem found by `ContentCatalog.validate()`.
public enum ContentIssue: Equatable, Sendable {
    case noConditions
    case duplicateID(String)
    case noVisibleSymptoms(String)
    case badWeight(String)
    case findingShownAsVisible(condition: String, symptom: Symptom)
    case visibleListedAsFinding(condition: String, symptom: Symptom)
    case unrevealableFinding(condition: String, symptom: Symptom)
    case indistinguishable(String, String)
}
