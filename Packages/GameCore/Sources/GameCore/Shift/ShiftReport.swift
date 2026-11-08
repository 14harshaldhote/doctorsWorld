/// The end-of-shift summary: what the results screen shows and what the
/// player profile records.
public struct ShiftReport: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let xpEarned: Int
    public let arrived: Int
    public let discharged: Int
    public let lost: Int
    public let handedOver: Int
    public let correctTriage: Int
    public let correctDiagnoses: Int
    public let wrongDiagnoses: Int
    public let perfectProcedures: Int
    public let bestStreak: Int
    public let reputationChange: Int

    init(shift: Shift) {
        var tally = Tally()
        for event in shift.events { tally.count(event) }
        seed = shift.config.seed
        xpEarned = tally.xp
        arrived = shift.patients.count
        discharged = shift.patients.filter { $0.location == .discharged }.count
        lost = shift.patients.filter { $0.location == .lost }.count
        handedOver = shift.patients.filter { $0.location == .handedOver }.count
        correctTriage = tally.correctTriage
        correctDiagnoses = tally.correctDiagnoses
        wrongDiagnoses = tally.wrongDiagnoses
        perfectProcedures = tally.perfect
        bestStreak = shift.bestStreak
        let tuning = shift.config.tuning
        reputationChange = discharged * tuning.reputationPerDischarge
            + lost * tuning.reputationPerLoss
            + tally.wrongDiagnoses * tuning.reputationPerWrongDiagnosis
    }

    /// A hand-made report, for tests and previews.
    init(xpEarned: Int, discharged: Int = 0, lost: Int = 0, bestStreak: Int = 0, reputationChange: Int = 0) {
        seed = 0
        self.xpEarned = xpEarned
        arrived = discharged + lost
        self.discharged = discharged
        self.lost = lost
        handedOver = 0
        correctTriage = 0
        correctDiagnoses = discharged
        wrongDiagnoses = 0
        perfectProcedures = 0
        self.bestStreak = bestStreak
        self.reputationChange = reputationChange
    }

    /// Share of diagnoses that were right, from 0 to 1 (1 when none were made).
    public var accuracy: Double {
        let total = correctDiagnoses + wrongDiagnoses
        return total == 0 ? 1 : Double(correctDiagnoses) / Double(total)
    }
}

private struct Tally {
    var xp = 0
    var correctTriage = 0
    var correctDiagnoses = 0
    var wrongDiagnoses = 0
    var perfect = 0

    mutating func count(_ event: ShiftEvent) {
        switch event {
        case .xp(let amount, _):
            xp += amount
        case .triaged(_, _, let correct):
            if correct { correctTriage += 1 }
        case .diagnosed(_, _, let correct):
            if correct { correctDiagnoses += 1 } else { wrongDiagnoses += 1 }
        case .treated(_, let grade):
            if grade == .perfect { perfect += 1 }
        default:
            break
        }
    }
}
