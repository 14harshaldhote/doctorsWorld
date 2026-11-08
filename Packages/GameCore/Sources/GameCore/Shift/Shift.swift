/// One shift on the ward: the whole game state and its rules.
///
/// A shift is a value. The screen keeps one, feeds it player actions with
/// `apply(_:)` and real time through `advance(ticks:)`, and draws whatever
/// it holds. The same config and the same actions at the same ticks always
/// produce exactly the same shift.
public struct Shift: Sendable, Equatable {
    /// Length of one rule step in game seconds.
    public static let step = GameClock.defaultStep

    public let config: ShiftConfig
    public let catalog: ContentCatalog
    public internal(set) var tick = 0
    public internal(set) var patients: [Patient] = []
    /// Which patient is in each bed, by bed number.
    public internal(set) var beds: [Int?]
    public internal(set) var events: [ShiftEvent] = []
    /// Patients treated cleanly in a row (no wrong guess, no poor procedure).
    public internal(set) var streak = 0
    public internal(set) var bestStreak = 0
    public internal(set) var isOver = false

    var generator: SeededRandom
    var nextArrivalTick = 0
    var nextPatientID = 1

    public init(config: ShiftConfig, catalog: ContentCatalog = .standard) {
        precondition(config.bedCount > 0, "a shift needs at least one bed")
        precondition(!catalog.conditions.isEmpty, "the catalog has no conditions")
        self.config = config
        self.catalog = catalog
        self.generator = SeededRandom(seed: config.seed)
        self.beds = Array(repeating: nil, count: config.bedCount)
        admitPatient()
    }

    // MARK: Reading the state

    /// Number of rule steps in the whole shift.
    public var durationTicks: Int { Self.ticks(for: config.duration) }
    /// Game seconds since the shift started.
    public var elapsed: Double { Double(tick) * Self.step }
    /// Game seconds left on the clock.
    public var remaining: Double { max(0, config.duration - elapsed) }

    public func patient(_ id: Int) -> Patient? {
        patients.first { $0.id == id }
    }

    public var waitingPatients: [Patient] { patients.filter { $0.location == .waiting } }

    /// Bed numbers with nobody in them.
    public var freeBeds: [Int] { beds.indices.filter { beds[$0] == nil } }

    /// The condition behind a patient. Only the rules and tests should peek.
    public func condition(of patient: Patient) -> Condition? {
        catalog.condition(patient.conditionID)
    }

    /// What the bedside monitor shows for a patient.
    public func vitals(of patient: Patient) -> Vitals {
        Vitals(stability: patient.stability, profile: condition(of: patient)?.vitals ?? .standard)
    }

    /// Total XP earned so far this shift.
    public var xpEarned: Int {
        events.reduce(0) { total, event in
            if case .xp(let amount, _) = event { return total + amount }
            return total
        }
    }

    /// The end-of-shift summary (also valid mid-shift).
    public var report: ShiftReport { ShiftReport(shift: self) }

    static func ticks(for seconds: Double) -> Int {
        max(1, Int((seconds / step).rounded()))
    }

    // MARK: Time

    /// Runs the rules forward. Stops early when the shift ends.
    public mutating func advance(ticks count: Int = 1) {
        guard count > 0 else { return }
        for _ in 0..<count {
            if isOver { return }
            stepOnce()
        }
    }

    private mutating func stepOnce() {
        tick += 1
        if tick >= nextArrivalTick && tick < durationTicks { admitPatient() }
        completeTests()
        applyDecline()
        if tick >= durationTicks { endShift() }
    }

    private mutating func admitPatient() {
        let condition = pickCondition()
        let id = nextPatientID
        nextPatientID += 1
        let name = PatientNames.name(using: &generator)
        let mentioned = config.tuning.presentingSymptoms + config.extraPresentingSymptoms
        let presenting = generator.shuffled(condition.visible).prefix(max(0, mentioned))
        let jitter = Double(generator.nextInt(in: -5...5))
        let stability = min(100, max(1, condition.severity.startStability + jitter))
        patients.append(Patient(
            id: id, name: name, conditionID: condition.id, arrivalTick: tick,
            stability: stability, knownSymptoms: Set(presenting)
        ))
        events.append(.arrived(patient: id))

        let range = config.arrivalInterval
        let gap = range.lowerBound + generator.nextDouble() * (range.upperBound - range.lowerBound)
        nextArrivalTick = tick + Self.ticks(for: gap)
    }

    private mutating func pickCondition() -> Condition {
        let total = catalog.conditions.reduce(0) { $0 + max(0, $1.weight) }
        var roll = generator.nextDouble() * total
        for condition in catalog.conditions {
            roll -= max(0, condition.weight)
            if roll < 0 { return condition }
        }
        return catalog.conditions[catalog.conditions.count - 1]
    }

    private mutating func completeTests() {
        for index in patients.indices {
            guard let pending = patients[index].pendingTest, pending.readyAtTick <= tick else { continue }
            let found = condition(of: patients[index])?.findings.filter { pending.test.reveals.contains($0) } ?? []
            patients[index].knownSymptoms.formUnion(found)
            patients[index].testsRun.append(pending.test)
            patients[index].pendingTest = nil
            events.append(.testResult(patient: patients[index].id, test: pending.test, found: found))
        }
    }

    private mutating func applyDecline() {
        for index in patients.indices where patients[index].isActive {
            guard let condition = self.condition(of: patients[index]) else { continue }
            var rate = condition.severity.declinePerSecond * config.declineMultiplier
            if patients[index].bed != nil {
                rate *= patients[index].diagnosis == nil ? config.bedDeclineFactor : config.tuning.diagnosedDeclineFactor
            }
            patients[index].stability = max(0, patients[index].stability - rate * Self.step)
            if patients[index].stability <= 0 { losePatient(at: index) }
        }
    }

    mutating func losePatient(at index: Int) {
        if let bed = patients[index].bed { beds[bed] = nil }
        patients[index].location = .lost
        patients[index].pendingTest = nil
        streak = 0
        events.append(.lost(patient: patients[index].id))
    }

    private mutating func endShift() {
        for index in patients.indices where patients[index].isActive {
            if let bed = patients[index].bed { beds[bed] = nil }
            patients[index].location = .handedOver
            patients[index].pendingTest = nil
        }
        isOver = true
        events.append(.shiftEnded)
    }

    mutating func award(_ amount: Int, for reason: XPReason) {
        guard amount > 0 else { return }
        events.append(.xp(amount: amount, reason: reason))
    }
}
