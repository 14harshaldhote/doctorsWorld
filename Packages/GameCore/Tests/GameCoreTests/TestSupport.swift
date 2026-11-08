@testable import GameCore

extension ShiftConfig {
    /// Only the first patient arrives; the next arrival is after the shift ends.
    static func quiet(seed: UInt64 = 1, duration: Double = 300) -> ShiftConfig {
        var config = ShiftConfig(seed: seed, duration: duration)
        config.arrivalInterval = 10_000...10_000
        return config
    }

    /// A new patient arrives exactly every `seconds`.
    static func every(_ seconds: Double, seed: UInt64 = 1, duration: Double = 300) -> ShiftConfig {
        var config = ShiftConfig(seed: seed, duration: duration)
        config.arrivalInterval = seconds...seconds
        return config
    }
}

extension Shift {
    /// A shift in which every patient has the given condition.
    static func only(_ conditionID: String, config: ShiftConfig = .quiet()) -> Shift {
        Shift(config: config, catalog: ContentCatalog.standard.only(conditionID))
    }

    /// The first patient of the shift.
    var first: Patient { patients[0] }

    /// XP amounts awarded for one reason, in order.
    func xpAwarded(for reason: XPReason) -> [Int] {
        events.compactMap { event in
            if case .xp(let amount, let why) = event, why == reason { return amount }
            return nil
        }
    }

    /// Puts the first patient in bed 0.
    mutating func seatFirst() throws {
        try apply(.assignBed(patient: first.id, bed: 0))
    }
}
