import Testing
@testable import GameCore

@Suite("Player profile")
struct ProfileTests {
    @Test("Recording a shift adds XP and counts")
    func recordAddsUp() {
        var player = PlayerProfile()
        player.record(ShiftReport(xpEarned: 300, discharged: 6, lost: 1, bestStreak: 4, reputationChange: 2))
        #expect(player.totalXP == 300)
        #expect(player.shiftsPlayed == 1)
        #expect(player.patientsDischarged == 6)
        #expect(player.patientsLost == 1)
        #expect(player.bestStreak == 4)
        #expect(player.reputation == 52)
    }

    @Test("Recording reports level-ups and promotions")
    func levelUp() {
        var player = PlayerProfile(totalXP: 1_990)
        let update = player.record(ShiftReport(xpEarned: 20))
        #expect(update.levelBefore == 3)
        #expect(update.levelAfter == 4)
        #expect(update.leveledUp)
        #expect(update.rankBefore == .intern)
        #expect(update.rankAfter == .juniorResident)
        #expect(update.rankedUp)
    }

    @Test("A quiet shift is not a level-up")
    func noLevelUp() {
        var player = PlayerProfile()
        let update = player.record(ShiftReport(xpEarned: 10))
        #expect(!update.leveledUp)
        #expect(!update.rankedUp)
        #expect(update.xpGained == 10)
    }

    @Test("Reputation stays between 0 and 100")
    func reputationClamped() {
        var player = PlayerProfile()
        player.record(ShiftReport(xpEarned: 0, reputationChange: 500))
        #expect(player.reputation == 100)
        player.record(ShiftReport(xpEarned: 0, reputationChange: -500))
        #expect(player.reputation == 0)
        #expect(PlayerProfile(reputation: 400).reputation == 100)
    }

    @Test("XP is never taken away")
    func noNegativeXP() {
        var player = PlayerProfile(totalXP: 100)
        let update = player.record(ShiftReport(xpEarned: -50))
        #expect(player.totalXP == 100)
        #expect(update.xpGained == 0)
    }

    @Test("The best streak only goes up")
    func bestStreakKept() {
        var player = PlayerProfile()
        player.record(ShiftReport(xpEarned: 0, bestStreak: 6))
        player.record(ShiftReport(xpEarned: 0, bestStreak: 2))
        #expect(player.bestStreak == 6)
    }
}

@Suite("Shift difficulty")
struct DifficultyTests {
    @Test("An intern gets the baseline shift")
    func internBaseline() {
        let config = ShiftConfig.forPlayer(PlayerProfile(), seed: 3)
        #expect(config.seed == 3)
        #expect(config.declineMultiplier == 1)
        #expect(config.arrivalInterval == 30...50)
        #expect(config.extraPresentingSymptoms == 0)
        #expect(config.testDurationMultiplier == 1)
        #expect(config.bedDeclineFactor == Tuning.standard.bedDeclineFactor)
    }

    @Test("Higher ranks get busier shifts with faster decline")
    func harderWithRank() {
        let attending = PlayerProfile(totalXP: LevelCurve.totalXP(toReach: 10))
        #expect(attending.rank == .attending)
        let config = ShiftConfig.forPlayer(attending, seed: 3)
        #expect(abs(config.declineMultiplier - 1.3) < 1e-9)
        #expect(abs(config.arrivalInterval.lowerBound - 25.5) < 1e-9)
        #expect(abs(config.arrivalInterval.upperBound - 42.5) < 1e-9)
    }

    @Test("Skills change the shift")
    func skillsShapeShift() {
        let player = PlayerProfile(skills: [.keenEye, .quickLabs, .bedsideManner, .timeDilation, .goldenHour])
        let config = ShiftConfig.forPlayer(player, seed: 3)
        #expect(config.extraPresentingSymptoms == 1)
        #expect(config.testDurationMultiplier == 0.75)
        #expect(abs(config.bedDeclineFactor - 0.51) < 1e-9)
        #expect(abs(config.declineMultiplier - 0.9) < 1e-9)
    }
}
