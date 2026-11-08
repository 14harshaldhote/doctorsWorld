/// Everything that carries over between shifts.
public struct PlayerProfile: Codable, Sendable, Equatable {
    public static let startingReputation = 50
    public static let reputationRange = 0...100

    public private(set) var totalXP: Int
    /// Unlocked skills, always in a fixed order so saves are stable.
    public private(set) var skills: [Skill]
    /// The hospital's standing, from 0 to 100.
    public private(set) var reputation: Int
    public private(set) var shiftsPlayed: Int
    public private(set) var bestStreak: Int
    public private(set) var patientsDischarged: Int
    public private(set) var patientsLost: Int

    public init(totalXP: Int = 0, skills: [Skill] = [], reputation: Int = PlayerProfile.startingReputation) {
        self.totalXP = max(0, totalXP)
        self.skills = Array(Set(skills)).sorted { $0.order < $1.order }
        self.reputation = Self.clampReputation(reputation)
        self.shiftsPlayed = 0
        self.bestStreak = 0
        self.patientsDischarged = 0
        self.patientsLost = 0
    }

    public var level: Int { LevelCurve.level(forTotalXP: totalXP) }
    public var rank: Rank { .forLevel(level) }
    public var progress: LevelProgress { LevelCurve.progress(forTotalXP: totalXP) }

    /// One point per level gained, minus points already spent.
    public var skillPoints: Int { max(0, level - 1 - skills.count) }

    public func has(_ skill: Skill) -> Bool { skills.contains(skill) }

    public func canUnlock(_ skill: Skill) -> Bool { (try? checkUnlock(skill)) != nil }

    public mutating func unlock(_ skill: Skill) throws {
        try checkUnlock(skill)
        skills.append(skill)
        skills.sort { $0.order < $1.order }
    }

    private func checkUnlock(_ skill: Skill) throws {
        guard !has(skill) else { throw SkillError.alreadyUnlocked }
        if let needed = skill.prerequisite, !has(needed) { throw SkillError.missingPrerequisite(needed) }
        guard skillPoints > 0 else { throw SkillError.notEnoughPoints }
    }

    /// Adds a finished shift to the profile and says what changed.
    @discardableResult
    public mutating func record(_ report: ShiftReport) -> ProgressUpdate {
        let levelBefore = level
        let rankBefore = rank
        let reputationBefore = reputation
        totalXP += max(0, report.xpEarned)
        reputation = Self.clampReputation(reputation + report.reputationChange)
        shiftsPlayed += 1
        bestStreak = max(bestStreak, report.bestStreak)
        patientsDischarged += report.discharged
        patientsLost += report.lost
        return ProgressUpdate(
            xpGained: max(0, report.xpEarned),
            levelBefore: levelBefore, levelAfter: level,
            rankBefore: rankBefore, rankAfter: rank,
            reputationBefore: reputationBefore, reputationAfter: reputation
        )
    }

    static func clampReputation(_ value: Int) -> Int {
        min(max(value, reputationRange.lowerBound), reputationRange.upperBound)
    }
}

/// What changed when a shift was recorded, for the results screen.
public struct ProgressUpdate: Equatable, Sendable {
    public let xpGained: Int
    public let levelBefore: Int
    public let levelAfter: Int
    public let rankBefore: Rank
    public let rankAfter: Rank
    public let reputationBefore: Int
    public let reputationAfter: Int

    public var leveledUp: Bool { levelAfter > levelBefore }
    public var rankedUp: Bool { rankAfter > rankBefore }
}
