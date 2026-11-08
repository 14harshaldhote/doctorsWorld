extension ContentCatalog {
    /// The first-release ward: eight conditions with deliberate overlaps.
    ///
    /// Appendicitis and food poisoning look identical from the outside and
    /// need a blood test or scan to tell apart. Dizziness, swelling and
    /// shortness of breath each point to more than one condition.
    public static let standard = ContentCatalog(conditions: [
        Condition(
            id: "dehydration", name: "Dehydration", severity: .minor,
            visible: [.dizziness, .dryMouth, .fatigue], findings: [.dehydratedBlood],
            procedure: .ivDrip, weight: 1.2,
            vitals: VitalsProfile(heartRateRise: 45, oxygenDrop: 3, pressureDrop: 35)
        ),
        Condition(
            id: "brokenArm", name: "Broken arm", severity: .moderate,
            visible: [.limbPain, .swelling, .bruising], findings: [.brokenBone],
            procedure: .splint, weight: 1,
            vitals: VitalsProfile(heartRateRise: 30, oxygenDrop: 2, pressureDrop: 15)
        ),
        Condition(
            id: "allergicReaction", name: "Allergic reaction", severity: .severe,
            visible: [.rash, .swelling, .shortnessOfBreath], findings: [.allergyMarkers],
            procedure: .injection, weight: 0.8,
            vitals: VitalsProfile(heartRateRise: 55, oxygenDrop: 14, pressureDrop: 45)
        ),
        Condition(
            id: "asthmaAttack", name: "Asthma attack", severity: .severe,
            visible: [.shortnessOfBreath, .wheezing, .chestTightness], findings: [.lungSpasm],
            procedure: .medication, weight: 0.8,
            vitals: VitalsProfile(heartRateRise: 45, oxygenDrop: 18, pressureDrop: 10)
        ),
        Condition(
            id: "appendicitis", name: "Appendicitis", severity: .severe,
            visible: [.abdominalPain, .nausea, .fever], findings: [.inflamedAppendix, .highWhiteCells],
            procedure: .surgery, weight: 0.7,
            vitals: VitalsProfile(heartRateRise: 40, oxygenDrop: 4, pressureDrop: 30)
        ),
        Condition(
            id: "foodPoisoning", name: "Food poisoning", severity: .moderate,
            visible: [.abdominalPain, .nausea, .fever], findings: [.bacteriaInSample],
            procedure: .ivDrip, weight: 1,
            vitals: VitalsProfile(heartRateRise: 35, oxygenDrop: 3, pressureDrop: 30)
        ),
        Condition(
            id: "concussion", name: "Concussion", severity: .moderate,
            visible: [.headache, .dizziness, .confusion], findings: [.mildBrainInjury],
            procedure: .medication, weight: 0.9,
            vitals: VitalsProfile(heartRateRise: 25, oxygenDrop: 4, pressureDrop: 10)
        ),
        Condition(
            id: "deepCut", name: "Deep cut", severity: .moderate,
            visible: [.bleeding, .deepWound], findings: [],
            procedure: .suture, weight: 1,
            vitals: VitalsProfile(heartRateRise: 50, oxygenDrop: 5, pressureDrop: 50)
        )
    ])
}
