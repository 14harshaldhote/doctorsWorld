import Testing
@testable import GameCore

@Suite("Level curve and ranks")
struct LevelCurveTests {
    @Test("XP needed to reach a level", arguments: zip([0, 1, 2, 3, 4, 10], [0, 0, 710, 1_300, 2_000, 7_910]))
    func curve(level: Int, expected: Int) {
        #expect(LevelCurve.totalXP(toReach: level) == expected)
    }

    @Test("Level from total XP", arguments: zip([0, 709, 710, 1_999, 2_000, 7_910], [1, 1, 2, 3, 4, 10]))
    func levelFromXP(xp: Int, expected: Int) {
        #expect(LevelCurve.level(forTotalXP: xp) == expected)
    }

    @Test("Each level costs more than the one before")
    func increasing() {
        for level in 2..<LevelCurve.maxLevel {
            #expect(LevelCurve.totalXP(toReach: level + 1) > LevelCurve.totalXP(toReach: level))
        }
    }

    @Test("Levels stop at the maximum")
    func capped() {
        #expect(LevelCurve.level(forTotalXP: 100_000_000) == LevelCurve.maxLevel)
        #expect(LevelCurve.progress(forTotalXP: 100_000_000).fraction == 1)
    }

    @Test("Progress inside a level fills the XP bar")
    func progressBar() {
        let progress = LevelCurve.progress(forTotalXP: 1_000)
        #expect(progress.level == 2)
        #expect(progress.xpIntoLevel == 290)
        #expect(progress.xpForLevel == 590)
        #expect(progress.fraction > 0.49 && progress.fraction < 0.5)
    }

    @Test(
        "Rank for a level",
        arguments: zip(
            [1, 3, 4, 6, 7, 10, 13, 16, 19, 40],
            [Rank.intern, .intern, .juniorResident, .juniorResident, .seniorResident,
             .attending, .specialist, .departmentHead, .chief, .chief]
        )
    )
    func rankForLevel(level: Int, expected: Rank) {
        #expect(Rank.forLevel(level) == expected)
    }

    @Test("Each rank starts where the previous one ends")
    func rankBoundaries() {
        for rank in Rank.allCases {
            #expect(Rank.forLevel(rank.firstLevel) == rank)
            if rank.firstLevel > 1 {
                #expect(Rank.forLevel(rank.firstLevel - 1) < rank)
            }
        }
    }

    @Test("Every rank has a title")
    func titles() {
        #expect(Rank.intern.title == "Intern")
        #expect(Rank.chief.title == "Chief of Medicine")
        #expect(Rank.allCases.allSatisfy { !$0.title.isEmpty })
    }
}

@Suite("Skills")
struct SkillTests {
    @Test("Three branches of three skills, each needing the one before")
    func treeShape() {
        for branch in SkillBranch.allCases {
            let skills = Skill.allCases.filter { $0.branch == branch }
            #expect(skills.count == 3)
            #expect(skills[0].prerequisite == nil)
            #expect(skills[1].prerequisite == skills[0])
            #expect(skills[2].prerequisite == skills[1])
        }
        #expect(Skill.allCases.allSatisfy { !$0.title.isEmpty && !$0.summary.isEmpty })
    }

    @Test("Each level after the first gives one skill point")
    func skillPoints() {
        #expect(PlayerProfile().skillPoints == 0)
        #expect(PlayerProfile(totalXP: 2_000).skillPoints == 3)
        #expect(PlayerProfile(totalXP: 2_000, skills: [.keenEye]).skillPoints == 2)
    }

    @Test("Unlocking needs a free point, the prerequisite, and a new skill")
    func unlockRules() throws {
        var newcomer = PlayerProfile()
        #expect(throws: SkillError.notEnoughPoints) { try newcomer.unlock(.keenEye) }

        var player = PlayerProfile(totalXP: 2_000)
        #expect(throws: SkillError.missingPrerequisite(.keenEye)) { try player.unlock(.quickLabs) }
        #expect(!player.canUnlock(.quickLabs))
        #expect(player.canUnlock(.keenEye))
        try player.unlock(.keenEye)
        #expect(throws: SkillError.alreadyUnlocked) { try player.unlock(.keenEye) }
        try player.unlock(.quickLabs)
        #expect(player.skillPoints == 1)
    }

    @Test("Skills are kept in a fixed order with no duplicates")
    func skillOrder() throws {
        var player = PlayerProfile(totalXP: 2_000)
        try player.unlock(.bedsideManner)
        try player.unlock(.keenEye)
        #expect(player.skills == [.keenEye, .bedsideManner])
        #expect(PlayerProfile(skills: [.goldenHour, .keenEye, .keenEye]).skills == [.keenEye, .goldenHour])
    }
}
