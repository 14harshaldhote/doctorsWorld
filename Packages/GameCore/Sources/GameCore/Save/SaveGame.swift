import Foundation

/// The saved game: a version number plus the player profile.
///
/// The version lets future builds migrate old saves instead of losing them.
/// A save from a newer build is refused rather than misread.
public struct SaveGame: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public let version: Int
    public var profile: PlayerProfile

    public init(profile: PlayerProfile) {
        self.version = Self.currentVersion
        self.profile = profile
    }

    /// Stable, human-readable JSON (sorted keys), so two saves of the same
    /// profile are byte-for-byte identical.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }

    /// Reads a save, checking its version first.
    public static func decode(from data: Data) throws -> SaveGame {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(VersionProbe.self, from: data), let version = probe.version else {
            throw SaveError.corrupt
        }
        guard version <= currentVersion else { throw SaveError.newerVersion(version) }
        guard version >= 1 else { throw SaveError.corrupt }
        do {
            return try decoder.decode(SaveGame.self, from: data)
        } catch {
            throw SaveError.corrupt
        }
    }

    private struct VersionProbe: Decodable {
        let version: Int?
    }
}

/// Why a save could not be read.
public enum SaveError: Error, Equatable, Sendable {
    case corrupt
    case newerVersion(Int)
}

/// Somewhere a save can live.
public protocol SaveStore: Sendable {
    /// The saved game, or `nil` if nothing has been saved yet.
    func load() throws -> SaveGame?
    func save(_ game: SaveGame) throws
}

/// Keeps the save as a JSON file, written atomically so a crash mid-save
/// never leaves a half-written file.
public struct FileSaveStore: SaveStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The standard location inside the app's Application Support folder.
    public static func standard() throws -> FileSaveStore {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileSaveStore(url: folder.appendingPathComponent("DoctorsWorld").appendingPathComponent("save.json"))
    }

    public func load() throws -> SaveGame? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try SaveGame.decode(from: Data(contentsOf: url))
    }

    public func save(_ game: SaveGame) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try game.encoded().write(to: url, options: .atomic)
    }
}
