/// A computer player. It plays whole shifts for simulation tests and
/// balance checks, and can later power a demo mode.
public struct AutoPlayer: Sendable {
    /// How the auto-player behaves.
    public struct Style: Sendable, Equatable {
        /// Game seconds between actions, standing in for a human's reaction time.
        public var thinkSeconds: Double
        /// Chance of naming the wrong condition when sure.
        public var mistakeChance: Double
        public var perfectChance: Double
        public var goodChance: Double

        public init(thinkSeconds: Double, mistakeChance: Double, perfectChance: Double, goodChance: Double) {
            self.thinkSeconds = thinkSeconds
            self.mistakeChance = mistakeChance
            self.perfectChance = perfectChance
            self.goodChance = goodChance
        }

        /// Never wrong, always perfect, quick.
        public static let expert = Style(thinkSeconds: 2, mistakeChance: 0, perfectChance: 1, goodChance: 0)
        /// A typical new player: slower, sometimes wrong, mostly good procedures.
        public static let average = Style(thinkSeconds: 6, mistakeChance: 0.15, perfectChance: 0.2, goodChance: 0.5)
    }

    public var style: Style
    private var generator: SeededRandom

    public init(style: Style, seed: UInt64) {
        self.style = style
        self.generator = SeededRandom(seed: seed ^ 0xA5A5_A5A5_A5A5_A5A5)
    }

    /// Plays until the shift ends. Returns how many of its actions were
    /// refused, which should always be zero.
    @discardableResult
    public mutating func play(_ shift: inout Shift) -> Int {
        var refused = 0
        let thinkTicks = Shift.ticks(for: style.thinkSeconds)
        while !shift.isOver {
            if let action = nextAction(in: shift) {
                do { try shift.apply(action) } catch { refused += 1 }
            }
            shift.advance(ticks: thinkTicks)
        }
        return refused
    }

    /// The next thing to do, or `nil` to wait.
    public mutating func nextAction(in shift: Shift) -> ShiftAction? {
        if let bed = shift.freeBeds.first, let patient = mostUrgentWaiting(in: shift) {
            return .assignBed(patient: patient.id, bed: bed)
        }
        for case let id? in shift.beds {
            guard let patient = shift.patient(id), patient.pendingTest == nil else { continue }
            if let action = work(on: patient, in: shift) { return action }
        }
        return nil
    }

    private func mostUrgentWaiting(in shift: Shift) -> Patient? {
        shift.waitingPatients.min { lhs, rhs in
            lhs.stability == rhs.stability ? lhs.id < rhs.id : lhs.stability < rhs.stability
        }
    }

    private mutating func work(on patient: Patient, in shift: Shift) -> ShiftAction? {
        if patient.diagnosis != nil { return .treat(patient: patient.id, grade: pickGrade()) }
        if !patient.examined { return .examine(patient: patient.id) }
        let candidates = Diagnosis.candidates(for: patient, in: shift.catalog)
        if candidates.count > 1, let test = Diagnosis.usefulTests(for: patient, in: shift.catalog).first {
            return .runTest(patient: patient.id, test: test)
        }
        guard let best = candidates.first ?? shift.catalog.conditions.first else { return nil }
        return .diagnose(patient: patient.id, condition: pickDiagnosis(best: best, in: shift.catalog))
    }

    private mutating func pickDiagnosis(best: Condition, in catalog: ContentCatalog) -> String {
        guard generator.chance(style.mistakeChance) else { return best.id }
        let others = catalog.conditions.filter { $0.id != best.id }
        return generator.pick(from: others)?.id ?? best.id
    }

    private mutating func pickGrade() -> ProcedureGrade {
        let roll = generator.nextDouble()
        if roll < style.perfectChance { return .perfect }
        if roll < style.perfectChance + style.goodChance { return .good }
        return .poor
    }
}
