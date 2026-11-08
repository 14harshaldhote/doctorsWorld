/// Something a patient shows, says or a test finds.
///
/// Visible symptoms can be seen on arrival or found by examining the patient.
/// Findings only show up in a diagnostic test.
public enum Symptom: String, Codable, CaseIterable, Sendable, Comparable {
    // Visible
    case dizziness, dryMouth, fatigue
    case limbPain, swelling, bruising
    case rash, shortnessOfBreath, wheezing, chestTightness
    case abdominalPain, nausea, fever
    case headache, confusion
    case bleeding, deepWound

    // Findings (test results)
    case dehydratedBlood, highWhiteCells, bacteriaInSample
    case brokenBone
    case inflamedAppendix, mildBrainInjury
    case allergyMarkers
    case lungSpasm

    /// Symptoms that only a diagnostic test can reveal.
    public static let findings: Set<Symptom> = [
        .dehydratedBlood, .highWhiteCells, .bacteriaInSample, .brokenBone,
        .inflamedAppendix, .mildBrainInjury, .allergyMarkers, .lungSpasm
    ]

    /// `true` when only a diagnostic test can reveal this symptom.
    public var isFinding: Bool { Self.findings.contains(self) }

    /// Readable name, for example "Shortness of breath".
    public var displayName: String { readableName(rawValue) }

    public static func < (lhs: Symptom, rhs: Symptom) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Turns a camelCase identifier into a sentence-case phrase.
func readableName(_ identifier: String) -> String {
    var words = ""
    for character in identifier {
        if character.isUppercase {
            words += " " + character.lowercased()
        } else {
            words.append(character)
        }
    }
    return words.prefix(1).uppercased() + words.dropFirst()
}
