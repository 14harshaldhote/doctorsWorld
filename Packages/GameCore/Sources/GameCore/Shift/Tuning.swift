/// Every balance number in one place, so tuning never touches game logic.
public struct Tuning: Codable, Sendable, Equatable {
    /// XP for seating the most urgent waiting patient first.
    public var triageXP = 5
    /// XP for a correct diagnosis.
    public var diagnosisXP = 20
    /// Diagnosis XP is multiplied by this when two or more tests were needed.
    public var manyTestsFactor = 0.5
    public var perfectXP = 30
    public var goodXP = 15
    public var poorXP = 5
    /// XP for sending a patient home.
    public var dischargeXP = 10
    /// Treatment XP bonus per patient in the current clean streak.
    public var streakStep = 0.1
    /// Streak length at which the bonus stops growing (5 steps of 10% = +50%).
    public var streakCap = 5
    /// Stability lost when the player names the wrong condition.
    public var wrongDiagnosisPenalty = 10.0
    /// Decline speed for a patient in a bed but not yet diagnosed.
    public var bedDeclineFactor = 0.6
    /// Decline speed for a diagnosed patient waiting for treatment.
    public var diagnosedDeclineFactor = 0.3
    /// Visible symptoms a patient mentions on arrival.
    public var presentingSymptoms = 2
    public var reputationPerDischarge = 1
    public var reputationPerLoss = -4
    public var reputationPerWrongDiagnosis = -1

    public init() {}

    public static let standard = Tuning()

    /// XP for a procedure of the given grade.
    public func xp(for grade: ProcedureGrade) -> Int {
        switch grade {
        case .perfect: perfectXP
        case .good: goodXP
        case .poor: poorXP
        }
    }
}
