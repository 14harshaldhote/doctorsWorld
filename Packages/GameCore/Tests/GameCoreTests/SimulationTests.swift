import Testing
@testable import GameCore

@Suite("Simulated shifts")
struct SimulationTests {
    private func playedShift(seed: UInt64, style: AutoPlayer.Style) -> (shift: Shift, refused: Int) {
        var shift = Shift(config: ShiftConfig(seed: seed))
        var player = AutoPlayer(style: style, seed: seed)
        let refused = player.play(&shift)
        return (shift, refused)
    }

    @Test("A whole shift replays identically from its seed")
    func replayIsExact() {
        let first = playedShift(seed: 2_024, style: .expert)
        let second = playedShift(seed: 2_024, style: .expert)
        #expect(first.shift == second.shift)
        #expect(first.shift.report == second.shift.report)
        #expect(first.shift.events == second.shift.events)
    }

    @Test("Different seeds play out differently")
    func seedsDiffer() {
        let first = playedShift(seed: 1, style: .expert)
        let second = playedShift(seed: 2, style: .expert)
        #expect(first.shift.events != second.shift.events)
    }

    @Test("The auto-player never tries an illegal move", arguments: [AutoPlayer.Style.expert, .average])
    func legalMoves(style: AutoPlayer.Style) {
        for seed in UInt64(1)...20 {
            #expect(playedShift(seed: seed, style: style).refused == 0)
        }
    }

    @Test("An expert loses nobody and treats most patients")
    func expertShift() {
        for seed in UInt64(1)...20 {
            let report = playedShift(seed: seed, style: .expert).shift.report
            #expect(report.lost == 0, "seed \(seed) lost \(report.lost)")
            #expect(report.discharged >= 5, "seed \(seed) discharged only \(report.discharged)")
            #expect(report.wrongDiagnoses == 0)
        }
    }

    @Test("Every finished shift accounts for every patient")
    func everyoneAccountedFor() {
        for seed in UInt64(1)...30 {
            let report = playedShift(seed: seed, style: .average).shift.report
            #expect(report.arrived == report.discharged + report.lost + report.handedOver)
            #expect(report.xpEarned >= 0)
            #expect((0...1).contains(report.accuracy))
        }
    }

    @Test("100 seeded shifts never reach an impossible state")
    func invariantsHold() {
        for seed in UInt64(1)...100 {
            var shift = Shift(config: ShiftConfig(seed: seed))
            var player = AutoPlayer(style: .average, seed: seed)
            while !shift.isOver {
                if let action = player.nextAction(in: shift) { _ = try? shift.apply(action) }
                shift.advance(ticks: Shift.ticks(for: AutoPlayer.Style.average.thinkSeconds))
                checkInvariants(of: shift, seed: seed)
            }
            #expect(shift.patients.allSatisfy { !$0.isActive })
        }
    }

    private func checkInvariants(of shift: Shift, seed: UInt64) {
        for (bed, occupant) in shift.beds.enumerated() {
            guard let occupant else { continue }
            #expect(shift.patient(occupant)?.location == .bed(bed), "seed \(seed): bed \(bed) mismatch")
        }
        for patient in shift.patients {
            #expect((0...100).contains(patient.stability), "seed \(seed): stability out of range")
            if let bed = patient.bed {
                #expect(shift.beds[bed] == patient.id, "seed \(seed): patient \(patient.id) not in bed \(bed)")
            }
            if patient.isActive {
                let ids = Diagnosis.candidates(for: patient, in: shift.catalog).map(\.id)
                #expect(ids.contains(patient.conditionID), "seed \(seed): real condition ruled out")
            }
        }
    }
}

@Suite("Balance")
struct BalanceTests {
    /// Plays shift after shift with the given style until the player reaches `rank`.
    private func shiftsToReach(_ rank: Rank, style: AutoPlayer.Style, career: UInt64) -> Int {
        var profile = PlayerProfile()
        var shifts = 0
        while profile.rank < rank && shifts < 40 {
            let seed = career &* 1_000 &+ UInt64(shifts)
            var shift = Shift(config: .forPlayer(profile, seed: seed))
            var player = AutoPlayer(style: style, seed: seed)
            player.play(&shift)
            profile.record(shift.report)
            shifts += 1
        }
        return shifts
    }

    @Test("An average player reaches Junior Resident in 4 to 8 shifts")
    func averageCareer() {
        let careers = (UInt64(1)...11).map { shiftsToReach(.juniorResident, style: .average, career: $0) }.sorted()
        let median = careers[careers.count / 2]
        print("Shifts to Junior Resident for an average player:", careers, "median", median)
        #expect((4...8).contains(median))
    }

    @Test("A good average shift earns a few hundred XP")
    func averageShiftXP() {
        let earned = (UInt64(1)...20).map { seed -> Int in
            var shift = Shift(config: ShiftConfig(seed: seed))
            var player = AutoPlayer(style: .average, seed: seed)
            player.play(&shift)
            return shift.xpEarned
        }
        let mean = earned.reduce(0, +) / earned.count
        print("Average-player XP per intern shift:", earned, "mean", mean)
        #expect((150...600).contains(mean))
    }
}
