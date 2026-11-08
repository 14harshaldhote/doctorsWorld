/// A fixed-step game clock.
///
/// The screen refreshes at 60 or 120 frames a second, but the rules always
/// advance in equal steps (0.1 game seconds by default). Feeding real frame
/// times into `advance(by:)` returns how many rule steps to run, so the game
/// plays the same on every device and in tests.
///
/// A long pause (the app sent to the background, a debugger break) would
/// otherwise create a huge backlog of steps. The clock caps the steps per
/// call and drops the rest, so the game never fast-forwards on resume.
public struct GameClock: Sendable, Equatable {
    /// Default length of one rule step, in game seconds.
    public static let defaultStep = 0.1

    /// Length of one rule step, in game seconds.
    public let step: Double
    /// The most steps a single `advance(by:)` call may return.
    public let maxStepsPerAdvance: Int
    /// Rule steps taken since the clock started.
    public private(set) var tick = 0

    /// Game time not yet turned into a whole step.
    private var carry = 0.0
    /// Absorbs floating point error so that, for example, 0.3 s is 3 steps.
    private static let tolerance = 1e-9

    public init(step: Double = GameClock.defaultStep, maxStepsPerAdvance: Int = 10) {
        precondition(step > 0, "step must be positive")
        precondition(maxStepsPerAdvance > 0, "maxStepsPerAdvance must be positive")
        self.step = step
        self.maxStepsPerAdvance = maxStepsPerAdvance
    }

    /// Game seconds elapsed, always an exact multiple of `step`.
    public var elapsed: Double { Double(tick) * step }

    /// Adds real time and returns how many rule steps to run now.
    /// Zero, negative, infinite and NaN inputs are ignored.
    @discardableResult
    public mutating func advance(by seconds: Double) -> Int {
        guard seconds > 0, seconds.isFinite else { return 0 }
        carry += seconds
        var steps = Int((carry / step + Self.tolerance).rounded(.down))
        if steps > maxStepsPerAdvance {
            steps = maxStepsPerAdvance
            carry = 0
        } else {
            carry = max(0, carry - Double(steps) * step)
        }
        tick += steps
        return steps
    }
}
