/// The job title that comes with a range of levels.
public enum Rank: Int, Codable, CaseIterable, Sendable, Comparable {
    case intern = 1
    case juniorResident
    case seniorResident
    case attending
    case specialist
    case departmentHead
    case chief

    /// The rank held at a level.
    public static func forLevel(_ level: Int) -> Rank {
        switch level {
        case ...3: .intern
        case 4...6: .juniorResident
        case 7...9: .seniorResident
        case 10...12: .attending
        case 13...15: .specialist
        case 16...18: .departmentHead
        default: .chief
        }
    }

    /// The first level of this rank.
    public var firstLevel: Int { (rawValue - 1) * 3 + 1 }

    public var title: String {
        switch self {
        case .intern: "Intern"
        case .juniorResident: "Junior Resident"
        case .seniorResident: "Senior Resident"
        case .attending: "Attending Doctor"
        case .specialist: "Specialist"
        case .departmentHead: "Department Head"
        case .chief: "Chief of Medicine"
        }
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}
