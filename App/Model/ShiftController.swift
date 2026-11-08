import GameCore
import Observation

/// Owns the shift that is being played and connects it to the screens.
///
/// The floor calls `frame(_:)` every display frame; taps and buttons call
/// `perform(_:)`. Screens read `shift`, which only changes when the rules
/// actually moved, so SwiftUI redraws about ten times a second, not sixty.
@MainActor
@Observable
final class ShiftController {
    /// A short message shown when the player tries something not allowed.
    struct Notice: Equatable, Identifiable {
        let id: Int
        let text: String
    }

    /// Seconds the finished floor stays on screen before the results.
    static let resultsDelay = 1.6

    private(set) var shift: Shift
    private(set) var selectedPatientID: Int?
    private(set) var isPaused = false
    private(set) var notice: Notice?
    /// The player's total XP when the shift started, for the live XP bar.
    let startingXP: Int

    @ObservationIgnored private var runner: ShiftRunner
    @ObservationIgnored private var unseenEvents: [ShiftEvent] = []
    @ObservationIgnored private var secondsSinceEnd = 0.0
    @ObservationIgnored private var hasFinished = false
    @ObservationIgnored private var noticeCount = 0
    private let onFinish: @MainActor (Shift) -> Void

    init(runner: ShiftRunner, startingXP: Int, onFinish: @escaping @MainActor (Shift) -> Void) {
        self.runner = runner
        self.shift = runner.shift
        self.startingXP = startingXP
        self.onFinish = onFinish
        publish()
    }

    var isAutoPlaying: Bool { runner.isAutoPlaying }

    /// Level progress including the XP earned so far this shift.
    var liveProgress: LevelProgress {
        LevelCurve.progress(forTotalXP: startingXP + shift.xpEarned)
    }

    /// Feeds one display frame of real time into the shift.
    func frame(_ seconds: Double) {
        if runner.frame(seconds: seconds) > 0 { publish() }
        guard shift.isOver, !hasFinished else { return }
        secondsSinceEnd += seconds
        if secondsSinceEnd >= Self.resultsDelay { finish() }
    }

    /// Applies a player action. Returns false, and shows why, if refused.
    @discardableResult
    func perform(_ action: ShiftAction) -> Bool {
        do {
            try runner.perform(action)
            publish()
            return true
        } catch let error as ShiftActionError {
            show(error.playerMessage)
            return false
        } catch {
            return false
        }
    }

    func select(_ patientID: Int?) {
        selectedPatientID = patientID
    }

    func togglePause() {
        isPaused.toggle()
        runner.isPaused = isPaused
    }

    /// Walks off the floor: the shift ends now and still counts.
    func endShiftNow() {
        runner.finishEarly()
        isPaused = false
        runner.isPaused = false
        publish()
        finish()
    }

    /// New events for the floor to animate. Each is returned once.
    func takeEvents() -> [ShiftEvent] {
        defer { unseenEvents.removeAll() }
        return unseenEvents
    }

    func dismissNotice(_ id: Int) {
        if notice?.id == id { notice = nil }
    }

    private func publish() {
        unseenEvents.append(contentsOf: runner.drainEvents())
        shift = runner.shift
        if let id = selectedPatientID, shift.patient(id)?.isActive != true {
            selectedPatientID = nil
        }
        if runner.isAutoPlaying, selectedPatientID == nil {
            selectedPatientID = shift.beds.compactMap { $0 }.first
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish(shift)
    }

    private func show(_ text: String) {
        noticeCount += 1
        notice = Notice(id: noticeCount, text: text)
    }
}
