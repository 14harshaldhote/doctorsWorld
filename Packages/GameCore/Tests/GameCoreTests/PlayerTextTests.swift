import Foundation
import Testing
@testable import GameCore

@Suite("Player-facing text")
struct PlayerTextTests {
    @Test("Shift clock readings", arguments: [
        (300.0, "5:00"), (245.0, "4:05"), (59.95, "1:00"), (61.0, "1:01"),
        (0.01, "0:01"), (0.0, "0:00"), (-3.0, "0:00"), (Double.infinity, "0:00"), (Double.nan, "0:00")
    ])
    func clock(seconds: Double, expected: String) {
        #expect(PlayerText.clock(seconds) == expected)
    }

    @Test("Gains and losses carry a sign")
    func signed() {
        #expect(PlayerText.signed(3) == "+3")
        #expect(PlayerText.signed(-4) == "-4")
        #expect(PlayerText.signed(0) == "0")
    }

    @Test("First names and test results read naturally")
    func names() {
        #expect(PlayerText.firstName("Maya R.") == "Maya")
        #expect(PlayerText.firstName("Solo") == "Solo")
        #expect(PlayerText.result([]) == "Nothing found")
        #expect(PlayerText.result([.highWhiteCells, .bacteriaInSample]) == "High white cells, Bacteria in sample")
    }

    @Test("Every refusal explains itself in a short sentence")
    func refusalMessages() {
        let errors: [ShiftActionError] = [
            .shiftOver, .unknownPatient, .unknownBed, .unknownCondition, .bedOccupied, .patientNotWaiting,
            .patientNotInBed, .alreadyExamined, .testAlreadyRunning, .testAlreadyDone, .alreadyDiagnosed, .notDiagnosed
        ]
        let messages = errors.map { $0.playerMessage }
        #expect(messages.allSatisfy { $0.hasSuffix(".") && $0.count < 60 })
        #expect(Set(messages).count == errors.count)
    }

    @Test("Status labels and the next rank")
    func labels() {
        #expect(PatientStatus.critical.label == "Critical")
        #expect(Rank.intern.next == .juniorResident)
        #expect(Rank.chief.next == nil)
    }

    @Test("Hints use the patient's first name")
    func hints() {
        #expect(Bedside.NextStep.findBed.hint(for: "Maya R.").contains("Maya"))
        #expect(Bedside.NextStep.treat(.ivDrip).hint(for: "Omar K.") == "Diagnosed. Treat Omar with an IV drip.")
        #expect(Bedside.NextStep.gone(.lost).hint(for: "Omar K.") == "Omar did not make it.")
    }

    @Test("Events become short captions with the right tone")
    func captions() throws {
        let shift = Shift.only("dehydration")
        let first = PlayerText.firstName(shift.first.name)
        func caption(_ event: ShiftEvent) -> EventCaption? { EventCaption.caption(for: event, in: shift) }

        #expect(caption(.arrived(patient: 1)) == EventCaption(text: "\(first) arrived", tone: .info, patientID: 1))
        #expect(caption(.triaged(patient: 1, bed: 0, correct: false))?.tone == .bad)
        #expect(caption(.xp(amount: 25, reason: .treatment))?.text == "+25 XP")
        #expect(caption(.testResult(patient: 1, test: .xRay, found: []))?.text == "X-ray: Nothing found")
        #expect(caption(.diagnosed(patient: 1, condition: "dehydration", correct: false))?.text == "Not dehydration")
        #expect(caption(.diagnosed(patient: 1, condition: "dehydration", correct: true))?.tone == .good)
        #expect(caption(.treated(patient: 1, grade: .perfect))?.text == "Perfect!")
        #expect(caption(.lost(patient: 1))?.tone == .bad)
        #expect(caption(.examined(patient: 1)) == nil)
    }
}

@Suite("Casebook")
struct CasebookTests {
    let casebook = ContentCatalog.standard.casebook

    @Test("One entry per condition, in catalog order")
    func entries() {
        #expect(casebook.map { $0.id } == ContentCatalog.standard.conditions.map { $0.id })
    }

    @Test("The casebook never gives away hidden findings")
    func noFindings() {
        for entry in casebook {
            #expect(entry.symptoms.allSatisfy { !$0.isFinding }, "\(entry.id) lists a finding")
            let condition = ContentCatalog.standard.condition(entry.id)
            #expect(Set(entry.symptoms) == Set(condition?.visible ?? []))
        }
    }

    @Test("Each entry names the tests that can confirm it")
    func confirmingTests() throws {
        func tests(_ id: String) throws -> [DiagnosticTest] {
            try #require(casebook.first { $0.id == id }).confirmingTests
        }
        #expect(try tests("appendicitis") == [.bloodTest, .scan])
        #expect(try tests("foodPoisoning") == [.bloodTest])
        #expect(try tests("brokenArm") == [.xRay])
        #expect(try tests("deepCut").isEmpty)
    }
}

@Suite("Shift overrides")
struct ShiftOverrideTests {
    @Test("No overrides change nothing")
    func none() {
        let config = ShiftConfig.forPlayer(PlayerProfile(), seed: 4)
        #expect(ShiftOverrides().applied(to: config) == config)
    }

    @Test("Duration and arrival overrides are applied and kept in range")
    func applied() {
        let base = ShiftConfig(seed: 1)
        #expect(ShiftOverrides(duration: 40).applied(to: base).duration == 40)
        #expect(ShiftOverrides(duration: 1).applied(to: base).duration == 5)
        #expect(ShiftOverrides(duration: 99_999).applied(to: base).duration == 1800)
        #expect(ShiftOverrides(duration: .nan).applied(to: base).duration == 300)
        #expect(ShiftOverrides(arrivalSeconds: 6).applied(to: base).arrivalInterval == 6...9)
        #expect(ShiftOverrides(arrivalSeconds: 0).applied(to: base).arrivalInterval == 2...3)
    }
}

@Suite("Loading a save safely")
struct SaveRecoveryTests {
    /// The backup file name and reason, if the save was set aside.
    private func setAside(_ outcome: LoadOutcome) -> (backup: String, reason: SaveError)? {
        guard case .setAside(let backup, let reason) = outcome else { return nil }
        return (backup.lastPathComponent, reason)
    }

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("No save starts a new career")
    func fresh() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = FileSaveStore(url: folder.appendingPathComponent("save.json")).loadOrStart()
        #expect(result.outcome == .fresh)
        #expect(result.outcome.canSave)
        #expect(result.game.profile == PlayerProfile())
    }

    @Test("A good save loads as it was")
    func loaded() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileSaveStore(url: folder.appendingPathComponent("save.json"))
        var profile = PlayerProfile()
        profile.record(ShiftReport(xpEarned: 300, discharged: 4))
        try store.save(SaveGame(profile: profile))

        let result = store.loadOrStart()
        #expect(result.outcome == .loaded)
        #expect(result.game.profile == profile)
    }

    @Test("A damaged save is moved aside, never overwritten")
    func damaged() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let store = FileSaveStore(url: url)
        let junk = Data("{ not json".utf8)

        try junk.write(to: url)
        let first = store.loadOrStart()
        #expect(first.outcome.canSave)
        #expect(setAside(first.outcome)?.backup == "save.unreadable.json")
        #expect(setAside(first.outcome)?.reason == .corrupt)
        let backup = folder.appendingPathComponent("save.unreadable.json")
        #expect(try Data(contentsOf: backup) == junk)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        try junk.write(to: url)
        #expect(setAside(store.loadOrStart().outcome)?.backup == "save.unreadable-2.json")
    }

    @Test("A save from a newer build is kept for that build")
    func newer() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        try Data(#"{"version": 2, "profile": {}}"#.utf8).write(to: url)

        let result = FileSaveStore(url: url).loadOrStart()
        #expect(setAside(result.outcome)?.backup == "save.unreadable.json")
        #expect(setAside(result.outcome)?.reason == .newerVersion(2))
        #expect(result.game.profile == PlayerProfile())
    }
}

@Suite("Shift verdicts")
struct VerdictTests {
    @Test("The verdict follows how the shift went")
    func verdicts() {
        #expect(PlayerText.verdict(for: ShiftReport(xpEarned: 0)) == "Nobody came in. Enjoy it while it lasts.")
        #expect(PlayerText.verdict(for: ShiftReport(xpEarned: 10, discharged: 1, lost: 2)).contains("a word"))
        #expect(PlayerText.verdict(for: ShiftReport(xpEarned: 90, discharged: 3, lost: 1)).contains("Welcome to medicine"))
        #expect(PlayerText.verdict(for: ShiftReport(xpEarned: 300, discharged: 6)).hasPrefix("Flawless"))
        #expect(PlayerText.verdict(for: ShiftReport(xpEarned: 100, discharged: 2)).hasPrefix("Everyone survived"))
    }
}
