/// Runs a shift in real time for the screen.
///
/// The screen calls `frame(seconds:)` once per display frame with the real
/// time that passed. The runner turns that into fixed rule steps, can pause,
/// can play faster or slower, and hands out each new event exactly once so
/// the floor can animate it. An optional auto-player can take the turns,
/// which powers demo mode and the end-to-end UI test.
public struct ShiftRunner: Sendable {
    /// Slowest and fastest allowed playback speed.
    public static let timeScaleRange = 0.25...8.0

    public private(set) var shift: Shift
    /// While paused, frames do nothing. Actions are still allowed.
    public var isPaused = false
    /// Game seconds per real second. 1 is normal speed.
    public var timeScale: Double {
        didSet { timeScale = Self.clampScale(timeScale) }
    }

    private var clock: GameClock
    private var eventCursor = 0
    private var autoPlayer: AutoPlayer?
    private var nextAutoTick = 0

    public init(shift: Shift, timeScale: Double = 1, autoPlayer: AutoPlayer? = nil) {
        self.shift = shift
        self.timeScale = Self.clampScale(timeScale)
        self.clock = GameClock(step: Shift.step)
        self.autoPlayer = autoPlayer
    }

    /// True when an auto-player is taking the turns.
    public var isAutoPlaying: Bool { autoPlayer != nil }

    /// Feeds one frame of real time and returns how many rule steps ran.
    @discardableResult
    public mutating func frame(seconds: Double) -> Int {
        guard !isPaused, !shift.isOver else { return 0 }
        let steps = clock.advance(by: seconds * timeScale)
        var ran = 0
        while ran < steps, !shift.isOver {
            takeAutoTurn()
            shift.advance(ticks: 1)
            ran += 1
        }
        return ran
    }

    /// Applies a player action. Throws, and changes nothing, if it is not allowed.
    public mutating func perform(_ action: ShiftAction) throws {
        try shift.apply(action)
    }

    /// Ends the shift now; everyone still on the ward is handed over.
    public mutating func finishEarly() {
        shift.finishEarly()
    }

    /// Events added since the last call, oldest first. Each event is
    /// returned exactly once.
    public mutating func drainEvents() -> [ShiftEvent] {
        guard eventCursor < shift.events.count else { return [] }
        let new = Array(shift.events[eventCursor...])
        eventCursor = shift.events.count
        return new
    }

    private mutating func takeAutoTurn() {
        guard var player = autoPlayer, shift.tick >= nextAutoTick else { return }
        if let action = player.nextAction(in: shift) {
            try? shift.apply(action)
        }
        autoPlayer = player
        nextAutoTick = shift.tick + Shift.ticks(for: player.style.thinkSeconds)
    }

    private static func clampScale(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, timeScaleRange.lowerBound), timeScaleRange.upperBound)
    }
}
