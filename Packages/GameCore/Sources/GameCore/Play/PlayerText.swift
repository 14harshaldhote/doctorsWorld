import Foundation

/// Words the player reads. Kept in the core so they are tested and the
/// screens never invent their own wording for a rule.
public enum PlayerText {
    /// A shift clock reading such as "4:05". Rounds up, so "0:00" means
    /// the time really is up.
    public static func clock(_ seconds: Double) -> String {
        let whole = seconds.isFinite ? Int(min(max(0, seconds), 359_999).rounded(.up)) : 0
        let minutes = whole / 60
        let rest = whole % 60
        return rest < 10 ? "\(minutes):0\(rest)" : "\(minutes):\(rest)"
    }

    /// A signed number for gains and losses, such as "+3" or "-4".
    public static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    /// The first name, for tight spaces on the floor.
    public static func firstName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name))
    }

    /// What to show for one test result.
    public static func result(_ found: [Symptom]) -> String {
        found.isEmpty ? "Nothing found" : found.map(\.displayName).joined(separator: ", ")
    }
}

extension ShiftActionError {
    /// A short explanation for the player when an action is refused.
    public var playerMessage: String {
        switch self {
        case .shiftOver: "The shift is over."
        case .unknownPatient: "That patient has already left."
        case .unknownBed: "There is no bed there."
        case .unknownCondition: "That condition is not in the casebook."
        case .bedOccupied: "That bed is taken."
        case .patientNotWaiting: "That patient already has a bed."
        case .patientNotInBed: "Put the patient in a bed first."
        case .alreadyExamined: "You have already examined this patient."
        case .testAlreadyRunning: "Wait for the test that is running."
        case .testAlreadyDone: "You already have that result."
        case .alreadyDiagnosed: "This patient is already diagnosed."
        case .notDiagnosed: "Diagnose the patient before treating them."
        }
    }
}

extension PatientStatus {
    /// "Stable", "Serious", "Critical" or "Crashed".
    public var label: String { rawValue.capitalized }
}

extension Rank {
    /// The rank after this one, or `nil` at the top.
    public var next: Rank? { Rank(rawValue: rawValue + 1) }
}

extension Procedure {
    /// The procedure in a sentence: "a splint", "an IV drip", "surgery".
    public var withArticle: String {
        switch self {
        case .suture: "stitches"
        case .injection: "an injection"
        case .ivDrip: "an IV drip"
        case .splint: "a splint"
        case .medication: "medication"
        case .surgery: "surgery"
        case .cpr: "CPR"
        }
    }
}

extension Bedside.NextStep {
    /// A one-line hint for the bedside panel.
    public func hint(for name: String) -> String {
        let first = PlayerText.firstName(name)
        switch self {
        case .findBed: return "Drag \(first) onto a free bed, or tap a free bed below."
        case .examine: return "Examine \(first) to see every symptom."
        case .waitForTest(let test): return "Waiting for the \(test.displayName.lowercased()) result."
        case .testOrDiagnose: return "Order a test if you are unsure, or make your diagnosis."
        case .treat(let procedure): return "Diagnosed. Treat \(first) with \(procedure.withArticle)."
        case .gone(.discharged): return "\(first) went home."
        case .gone(.lost): return "\(first) did not make it."
        case .gone: return "\(first) was handed over to the next shift."
        }
    }
}

/// A short floating caption for something that just happened.
public struct EventCaption: Sendable, Equatable {
    public enum Tone: Sendable, Equatable {
        case good, bad, info
    }

    public let text: String
    public let tone: Tone
    /// The patient it is about, so the floor can show it above them.
    public let patientID: Int?

    public init(text: String, tone: Tone, patientID: Int?) {
        self.text = text
        self.tone = tone
        self.patientID = patientID
    }

    /// The caption for an event, or `nil` for events that need none.
    /// XP captions carry no patient: the floor shows them near the last
    /// patient involved.
    public static func caption(for event: ShiftEvent, in shift: Shift) -> EventCaption? {
        func name(_ id: Int) -> String { PlayerText.firstName(shift.patient(id)?.name ?? "Patient") }
        func conditionName(_ id: String) -> String { shift.catalog.condition(id)?.name ?? id }

        switch event {
        case .arrived(let id):
            return EventCaption(text: "\(name(id)) arrived", tone: .info, patientID: id)
        case .triaged(let id, _, let correct):
            return correct
                ? EventCaption(text: "Good call", tone: .good, patientID: id)
                : EventCaption(text: "Someone sicker is waiting", tone: .bad, patientID: id)
        case .examined:
            return nil
        case .testStarted(let id, let test):
            return EventCaption(text: "\(test.displayName) ordered", tone: .info, patientID: id)
        case .testResult(let id, let test, let found):
            return EventCaption(text: "\(test.displayName): \(PlayerText.result(found))", tone: .info, patientID: id)
        case .diagnosed(let id, let condition, let correct):
            return correct
                ? EventCaption(text: conditionName(condition), tone: .good, patientID: id)
                : EventCaption(text: "Not \(conditionName(condition).lowercased())", tone: .bad, patientID: id)
        case .treated(let id, let grade):
            return EventCaption(text: grade == .perfect ? "Perfect!" : "Sent home", tone: .good, patientID: id)
        case .lost(let id):
            return EventCaption(text: "Lost \(name(id))", tone: .bad, patientID: id)
        case .xp(let amount, _):
            return EventCaption(text: "+\(amount) XP", tone: .good, patientID: nil)
        case .shiftEnded:
            return EventCaption(text: "Shift over", tone: .info, patientID: nil)
        }
    }
}

extension PlayerText {
    /// A one-line, slightly dark verdict on a finished shift.
    public static func verdict(for report: ShiftReport) -> String {
        if report.arrived == 0 { return "Nobody came in. Enjoy it while it lasts." }
        if report.lost > report.discharged { return "The hospital would like a word." }
        if report.lost > 0 { return "Some went home, some did not. Welcome to medicine." }
        if report.discharged == 0 { return "Nobody died, mostly because you did nothing. Bold." }
        if report.discharged >= 5 && report.wrongDiagnoses == 0 { return "Flawless. Nobody will ever thank you for it." }
        return "Everyone survived. A low bar, cleanly cleared."
    }
}
