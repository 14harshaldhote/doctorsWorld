import Foundation
import GameCore
import Observation

/// Settings read from launch arguments, for demo mode and the UI tests,
/// for example `-freshProfile YES -autoplay YES -shiftSeconds 20`.
struct LaunchOptions: Sendable {
    /// Play with a new career kept in memory; the real save is never touched.
    var freshProfile = false
    /// Let the computer play the shift.
    var autoplay = false
    var seed: UInt64?
    var overrides = ShiftOverrides()
    var timeScale = 1.0

    static func fromArguments(_ defaults: UserDefaults = .standard) -> LaunchOptions {
        var options = LaunchOptions()
        options.freshProfile = defaults.bool(forKey: "freshProfile")
        options.autoplay = defaults.bool(forKey: "autoplay")
        options.seed = defaults.string(forKey: "seed").flatMap { UInt64($0) }
        if defaults.object(forKey: "shiftSeconds") != nil {
            options.overrides.duration = defaults.double(forKey: "shiftSeconds")
        }
        if defaults.object(forKey: "arrivalSeconds") != nil {
            options.overrides.arrivalSeconds = defaults.double(forKey: "arrivalSeconds")
        }
        if defaults.object(forKey: "timeScale") != nil {
            options.timeScale = defaults.double(forKey: "timeScale")
        }
        return options
    }
}

/// What the results screen shows about a finished shift.
struct ShiftResult: Equatable {
    let report: ShiftReport
    let update: ProgressUpdate
    let progressBefore: LevelProgress
    let progressAfter: LevelProgress
}

/// The whole app: which screen is up, the player's career, and saving it.
@MainActor
@Observable
final class AppModel {
    enum Screen: Equatable {
        case title, shift, results
    }

    private(set) var screen = Screen.title
    private(set) var profile: PlayerProfile
    private(set) var shiftController: ShiftController?
    private(set) var lastResult: ShiftResult?
    /// A note for the title screen, for example about an unreadable save.
    private(set) var notice: String?

    private let store: FileSaveStore?
    @ObservationIgnored private var canSave: Bool
    let options: LaunchOptions

    init(options: LaunchOptions = .fromArguments()) {
        self.options = options
        var store: FileSaveStore?
        var profile = PlayerProfile()
        var canSave = false
        var notice: String?
        if !options.freshProfile {
            if let standard = try? FileSaveStore.standard() {
                let loaded = standard.loadOrStart()
                store = standard
                profile = loaded.game.profile
                canSave = loaded.outcome.canSave
                notice = Self.message(for: loaded.outcome)
            } else {
                notice = "Progress cannot be saved on this device right now."
            }
        }
        self.store = store
        self.profile = profile
        self.canSave = canSave
        self.notice = notice
    }

    func startShift() {
        let seed = options.seed ?? UInt64.random(in: 1...UInt64.max)
        let config = options.overrides.applied(to: .forPlayer(profile, seed: seed))
        let runner = ShiftRunner(
            shift: Shift(config: config),
            timeScale: options.timeScale,
            autoPlayer: options.autoplay ? AutoPlayer(style: .expert, seed: seed) : nil
        )
        shiftController = ShiftController(runner: runner, startingXP: profile.totalXP) { [weak self] shift in
            self?.finish(shift)
        }
        lastResult = nil
        notice = nil
        screen = .shift
    }

    func backToTitle() {
        screen = .title
        shiftController = nil
    }

    private func finish(_ shift: Shift) {
        let report = shift.report
        let before = profile.progress
        let update = profile.record(report)
        lastResult = ShiftResult(report: report, update: update, progressBefore: before, progressAfter: profile.progress)
        save()
        screen = .results
        shiftController = nil
    }

    private func save() {
        guard canSave, let store else { return }
        do {
            try store.save(SaveGame(profile: profile))
        } catch {
            notice = "Your progress could not be saved this time."
        }
    }

    private static func message(for outcome: LoadOutcome) -> String? {
        switch outcome {
        case .fresh, .loaded:
            nil
        case .setAside(_, .newerVersion):
            "Your save came from a newer version of the game, so it was kept aside and a new career started."
        case .setAside:
            "Your save could not be read, so it was kept aside and a new career started."
        case .leftInPlace:
            "Your save could not be read. A new career will run without saving until this is fixed."
        }
    }
}
