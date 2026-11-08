import Testing
@testable import GameCore

@Suite("GameClock")
struct GameClockTests {
    @Test("0.3 seconds is exactly three steps despite floating point error")
    func wholeStepsAreExact() {
        var clock = GameClock()
        #expect(clock.advance(by: 0.3) == 3)
        #expect(clock.tick == 3)
    }

    @Test("Frame rate does not change game time", arguments: [30, 60, 120])
    func frameRateIndependent(framesPerSecond: Int) {
        var clock = GameClock()
        let frame = 1.0 / Double(framesPerSecond)
        for _ in 0..<(framesPerSecond * 10) {
            clock.advance(by: frame)
        }
        #expect(clock.tick == 100)
        #expect(abs(clock.elapsed - 10) < 1e-9)
    }

    @Test("Partial steps carry over to the next frame")
    func partialStepsCarry() {
        var clock = GameClock()
        #expect(clock.advance(by: 0.05) == 0)
        #expect(clock.advance(by: 0.05) == 1)
        #expect(clock.advance(by: 0.25) == 2)
        #expect(clock.advance(by: 0.05) == 1)
    }

    @Test("A long pause is capped and does not fast-forward later")
    func longPauseIsCapped() {
        var clock = GameClock(maxStepsPerAdvance: 10)
        #expect(clock.advance(by: 5) == 10)
        #expect(clock.advance(by: 0.1) == 1)
        #expect(clock.tick == 11)
    }

    @Test("Bad inputs are ignored", arguments: [0, -1, Double.nan, Double.infinity, -Double.infinity])
    func badInputsIgnored(seconds: Double) {
        var clock = GameClock()
        #expect(clock.advance(by: seconds) == 0)
        #expect(clock.tick == 0)
        #expect(clock.advance(by: 0.1) == 1)
    }

    @Test("A custom step length is honoured")
    func customStep() {
        var clock = GameClock(step: 0.5)
        #expect(clock.advance(by: 1.6) == 3)
        #expect(clock.elapsed == 1.5)
    }
}
