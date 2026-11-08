import Foundation
import Testing
@testable import GameCore

@Suite("Saving and loading")
struct SaveTests {
    private func sampleProfile() throws -> PlayerProfile {
        var player = PlayerProfile(totalXP: 2_100, reputation: 63)
        try player.unlock(.keenEye)
        player.record(ShiftReport(xpEarned: 150, discharged: 5, lost: 0, bestStreak: 3, reputationChange: 5))
        return player
    }

    @Test("A save round-trips exactly")
    func roundTrip() throws {
        let game = SaveGame(profile: try sampleProfile())
        #expect(try SaveGame.decode(from: game.encoded()) == game)
    }

    @Test("Saving the same profile twice gives identical bytes")
    func stableBytes() throws {
        let game = SaveGame(profile: try sampleProfile())
        let first = try game.encoded()
        #expect(try game.encoded() == first)
        let text = try #require(String(data: first, encoding: .utf8))
        #expect(text.contains("\"version\" : 1"))
    }

    @Test("A version 1 save written by hand still loads")
    func versionOneFixture() throws {
        let json = """
        {"profile":{"bestStreak":4,"patientsDischarged":12,"patientsLost":1,"reputation":61,\
        "shiftsPlayed":3,"skills":["keenEye"],"totalXP":900},"version":1}
        """
        let game = try SaveGame.decode(from: Data(json.utf8))
        #expect(game.version == 1)
        #expect(game.profile.totalXP == 900)
        #expect(game.profile.level == 2)
        #expect(game.profile.skills == [.keenEye])
        #expect(game.profile.reputation == 61)
    }

    @Test("A save from a newer build is refused, not misread")
    func newerVersion() {
        let json = #"{"version": 2, "profile": {}}"#
        #expect(throws: SaveError.newerVersion(2)) { try SaveGame.decode(from: Data(json.utf8)) }
    }

    @Test("Broken saves are reported as corrupt", arguments: [
        "not json at all",
        #"{"profile": {}}"#,
        #"{"version": 0, "profile": {}}"#,
        #"{"version": 1, "profile": {"totalXP": "lots"}}"#
    ])
    func corrupt(json: String) {
        #expect(throws: SaveError.corrupt) { try SaveGame.decode(from: Data(json.utf8)) }
    }

    @Test("The file store saves, loads and overwrites")
    func fileStore() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileSaveStore(url: folder.appendingPathComponent("nested").appendingPathComponent("save.json"))

        #expect(try store.load() == nil)
        let first = SaveGame(profile: PlayerProfile(totalXP: 10))
        try store.save(first)
        #expect(try store.load() == first)

        let second = SaveGame(profile: try sampleProfile())
        try store.save(second)
        #expect(try store.load() == second)
    }

    @Test("A damaged save file is reported, not silently replaced")
    func damagedFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("save.json")
        try Data("{oops".utf8).write(to: url)
        #expect(throws: SaveError.corrupt) { try FileSaveStore(url: url).load() }
    }
}
