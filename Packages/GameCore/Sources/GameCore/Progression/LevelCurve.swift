import Foundation

/// How much experience each level needs.
///
/// Reaching level n takes a total of `base × n^1.5` XP, rounded to the
/// nearest 10. With the standard base of 250: level 2 at 710 XP, level 4
/// (Junior Resident) at 2,000 XP and level 10 at 7,910 XP.
public enum LevelCurve {
    public static let base = 250.0
    public static let maxLevel = 50

    /// Total XP needed to reach a level. Level 1 needs nothing.
    public static func totalXP(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        let raw = base * pow(Double(min(level, maxLevel)), 1.5)
        return Int((raw / 10).rounded()) * 10
    }

    /// The level a player with this much total XP has reached.
    public static func level(forTotalXP xp: Int) -> Int {
        var level = 1
        while level < maxLevel && xp >= totalXP(toReach: level + 1) {
            level += 1
        }
        return level
    }

    /// How far into the current level a player is, for the XP bar.
    public static func progress(forTotalXP xp: Int) -> LevelProgress {
        let level = Self.level(forTotalXP: xp)
        let start = totalXP(toReach: level)
        guard level < maxLevel else {
            return LevelProgress(level: level, xpIntoLevel: xp - start, xpForLevel: 0)
        }
        return LevelProgress(level: level, xpIntoLevel: xp - start, xpForLevel: totalXP(toReach: level + 1) - start)
    }
}

/// Position inside a level, for drawing an XP bar.
public struct LevelProgress: Equatable, Sendable {
    public let level: Int
    public let xpIntoLevel: Int
    /// XP between this level and the next; 0 at the maximum level.
    public let xpForLevel: Int

    /// From 0 to 1; 1 at the maximum level.
    public var fraction: Double {
        xpForLevel == 0 ? 1 : Double(xpIntoLevel) / Double(xpForLevel)
    }
}
