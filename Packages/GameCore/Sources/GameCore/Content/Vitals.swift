/// How strongly the monitor reacts as a patient's stability falls.
public struct VitalsProfile: Codable, Sendable, Equatable {
    /// Heart rate rise (beats per minute) at zero stability.
    public var heartRateRise: Double
    /// Oxygen saturation drop (percentage points) at zero stability.
    public var oxygenDrop: Double
    /// Systolic blood pressure drop (mmHg) at zero stability.
    public var pressureDrop: Double

    public init(heartRateRise: Double, oxygenDrop: Double, pressureDrop: Double) {
        self.heartRateRise = heartRateRise
        self.oxygenDrop = oxygenDrop
        self.pressureDrop = pressureDrop
    }

    public static let standard = VitalsProfile(heartRateRise: 40, oxygenDrop: 6, pressureDrop: 30)
}

/// The numbers on a bedside monitor, derived from stability so they always
/// tell the truth about how a patient is doing.
public struct Vitals: Codable, Sendable, Equatable {
    public var heartRate: Double
    public var oxygen: Double
    public var systolic: Double

    public static let healthy = Vitals(heartRate: 75, oxygen: 98, systolic: 120)

    public init(heartRate: Double, oxygen: Double, systolic: Double) {
        self.heartRate = heartRate
        self.oxygen = oxygen
        self.systolic = systolic
    }

    /// Monitor values for a patient at the given stability (0 to 100).
    public init(stability: Double, profile: VitalsProfile) {
        let strain = (100 - min(max(stability, 0), 100)) / 100
        self.init(
            heartRate: Self.healthy.heartRate + profile.heartRateRise * strain,
            oxygen: Self.healthy.oxygen - profile.oxygenDrop * strain,
            systolic: Self.healthy.systolic - profile.pressureDrop * strain
        )
    }
}

/// A plain-language reading of a patient's stability.
public enum PatientStatus: String, Codable, CaseIterable, Sendable, Comparable {
    case stable, serious, critical, crashed

    public init(stability: Double) {
        switch stability {
        case 60...: self = .stable
        case 30..<60: self = .serious
        case _ where stability > 0: self = .critical
        default: self = .crashed
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    public static func < (lhs: PatientStatus, rhs: PatientStatus) -> Bool { lhs.order < rhs.order }
}
