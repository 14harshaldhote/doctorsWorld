/// The rules for one shift: its seed, length, beds and difficulty.
public struct ShiftConfig: Codable, Sendable, Equatable {
    public var seed: UInt64
    /// Shift length in game seconds.
    public var duration: Double
    public var bedCount: Int
    /// Game seconds between arrivals, picked at random inside this range.
    public var arrivalInterval: ClosedRange<Double> = 30...50
    /// Scales how fast every patient declines.
    public var declineMultiplier = 1.0
    /// Decline speed for a patient in a bed but not yet diagnosed.
    public var bedDeclineFactor: Double
    /// Scales how long tests take.
    public var testDurationMultiplier = 1.0
    /// Extra symptoms patients mention on arrival.
    public var extraPresentingSymptoms = 0
    public var tuning: Tuning

    public init(seed: UInt64, duration: Double = 300, bedCount: Int = 3, tuning: Tuning = .standard) {
        self.seed = seed
        self.duration = duration
        self.bedCount = bedCount
        self.tuning = tuning
        self.bedDeclineFactor = tuning.bedDeclineFactor
    }

    /// A shift sized for the player: harder with each rank, and shaped by
    /// the skills they have unlocked.
    public static func forPlayer(_ profile: PlayerProfile, seed: UInt64) -> ShiftConfig {
        var config = ShiftConfig(seed: seed)
        let rankStep = Double(profile.rank.rawValue - 1)
        config.declineMultiplier = 1 + 0.1 * rankStep
        let pace = max(0.6, 1 - 0.05 * rankStep)
        config.arrivalInterval = (30 * pace)...(50 * pace)
        if profile.has(.keenEye) { config.extraPresentingSymptoms = 1 }
        if profile.has(.quickLabs) { config.testDurationMultiplier = 0.75 }
        if profile.has(.bedsideManner) { config.bedDeclineFactor *= 0.85 }
        if profile.has(.goldenHour) { config.declineMultiplier *= 0.9 }
        return config
    }
}

/// Shift settings that do not come from the player's profile. Demo mode and
/// the UI tests use them for short, busy shifts. Values are kept in sane
/// ranges so a bad launch argument cannot break a shift.
public struct ShiftOverrides: Sendable, Equatable {
    public static let durationRange = 5.0...1800.0
    public static let arrivalRange = 2.0...600.0

    /// Shift length in game seconds.
    public var duration: Double?
    /// Shortest gap between arrivals; the longest is 1.5 times this.
    public var arrivalSeconds: Double?

    public init(duration: Double? = nil, arrivalSeconds: Double? = nil) {
        self.duration = duration
        self.arrivalSeconds = arrivalSeconds
    }

    /// Applies the overrides to a config.
    public func applied(to config: ShiftConfig) -> ShiftConfig {
        var config = config
        if let duration, duration.isFinite {
            config.duration = Self.clamp(duration, to: Self.durationRange)
        }
        if let arrivalSeconds, arrivalSeconds.isFinite {
            let gap = Self.clamp(arrivalSeconds, to: Self.arrivalRange)
            config.arrivalInterval = gap...(gap * 1.5)
        }
        return config
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
