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

/// How the game came by the save it started with.
public enum LoadOutcome: Equatable, Sendable {
    /// No save yet: a brand new career.
    case fresh
    /// The save loaded normally.
    case loaded
    /// The save could not be read. It was moved aside to `backup`, never
    /// deleted, and a new career started.
    case setAside(backup: URL, reason: SaveError)
    /// The save could not be read or moved. It stays untouched, and the new
    /// career must not be saved over it.
    case leftInPlace(reason: SaveError)

    /// False when saving would overwrite a file the player may still want.
    public var canSave: Bool {
        if case .leftInPlace = self { return false }
        return true
    }
}

extension FileSaveStore {
    /// Loads the save, or starts a new career if there is none.
    ///
    /// An unreadable save (damaged, or written by a newer build) is renamed
    /// rather than overwritten, so a bug can never silently wipe someone's
    /// progress. If even the rename fails, the game still starts with a new
    /// career, and `canSave` is false so the old file is never overwritten.
    public func loadOrStart() -> (game: SaveGame, outcome: LoadOutcome) {
        do {
            if let game = try load() { return (game, .loaded) }
            return (SaveGame(profile: PlayerProfile()), .fresh)
        } catch {
            let reason = (error as? SaveError) ?? .corrupt
            let backup = setAsideURL()
            do {
                try FileManager.default.moveItem(at: url, to: backup)
            } catch {
                return (SaveGame(profile: PlayerProfile()), .leftInPlace(reason: reason))
            }
            return (SaveGame(profile: PlayerProfile()), .setAside(backup: backup, reason: reason))
        }
    }

    /// A free file name next to the save: save.unreadable.json, then
    /// save.unreadable-2.json and so on.
    private func setAsideURL() -> URL {
        let folder = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        var number = 1
        while true {
            let suffix = number == 1 ? "" : "-\(number)"
            let candidate = folder.appendingPathComponent("\(stem).unreadable\(suffix).json")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            number += 1
        }
    }
}
