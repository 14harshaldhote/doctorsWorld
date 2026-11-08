import Testing
@testable import GameCore

@Suite("Shift runner")
struct RunnerTests {
    @Test("Half a real second runs five rule steps")
    func framesBecomeSteps() {
        var runner = ShiftRunner(shift: Shift(config: .quiet()))
        #expect(runner.frame(seconds: 0.5) == 5)
        #expect(runner.shift.tick == 5)
        #expect(runner.frame(seconds: 1.0 / 60) == 0)
        #expect(runner.frame(seconds: 0.1) == 1)
    }

    @Test("Pausing stops time but still allows actions")
    func pausing() throws {
        var runner = ShiftRunner(shift: Shift(config: .quiet()))
        runner.isPaused = true
        #expect(runner.frame(seconds: 1) == 0)
        #expect(runner.shift.tick == 0)
        try runner.perform(.assignBed(patient: 1, bed: 0))
        #expect(runner.shift.first.location == .bed(0))
        runner.isPaused = false
        #expect(runner.frame(seconds: 0.3) == 3)
    }

    @Test("Time scale speeds the shift up or slows it down")
    func timeScale() {
        var fast = ShiftRunner(shift: Shift(config: .quiet()), timeScale: 2)
        #expect(fast.frame(seconds: 0.5) == 10)
        var slow = ShiftRunner(shift: Shift(config: .quiet()), timeScale: 0.5)
        #expect(slow.frame(seconds: 1) == 5)
    }

    @Test("Time scale is kept in a safe range")
    func timeScaleRange() {
        var runner = ShiftRunner(shift: Shift(config: .quiet()), timeScale: 100)
        #expect(runner.timeScale == 8)
        runner.timeScale = 0
        #expect(runner.timeScale == 0.25)
        runner.timeScale = .nan
        #expect(runner.timeScale == 1)
    }

    @Test("Each event is handed out exactly once")
    func drainEvents() throws {
        var runner = ShiftRunner(shift: Shift(config: .quiet()))
        #expect(runner.drainEvents() == [.arrived(patient: 1)])
        #expect(runner.drainEvents().isEmpty)
        try runner.perform(.assignBed(patient: 1, bed: 0))
        let events = runner.drainEvents()
        #expect(events == [.triaged(patient: 1, bed: 0, correct: true), .xp(amount: 5, reason: .triage)])
        #expect(runner.drainEvents().isEmpty)
    }

    @Test("A refused action changes nothing")
    func refusedAction() {
        var runner = ShiftRunner(shift: Shift(config: .quiet()))
        let before = runner.shift
        #expect(throws: ShiftActionError.patientNotInBed) {
            try runner.perform(.examine(patient: 1))
        }
        #expect(runner.shift == before)
    }

    @Test("Frames do nothing once the shift is over")
    func noTimeAfterEnd() {
        var runner = ShiftRunner(shift: Shift(config: .quiet(duration: 1)))
        for _ in 0..<5 { runner.frame(seconds: 0.5) }
        #expect(runner.shift.isOver)
        let tick = runner.shift.tick
        #expect(runner.frame(seconds: 1) == 0)
        #expect(runner.shift.tick == tick)
    }

    @Test("Finishing early hands everyone over, once")
    func finishEarly() throws {
        var runner = ShiftRunner(shift: Shift(config: .every(5)))
        runner.frame(seconds: 1)
        runner.frame(seconds: 1)
        runner.frame(seconds: 1)
        runner.frame(seconds: 1)
        runner.frame(seconds: 1)
        try runner.perform(.assignBed(patient: 1, bed: 0))
        runner.finishEarly()
        runner.finishEarly()

        #expect(runner.shift.isOver)
        #expect(runner.shift.patients.allSatisfy { $0.location == .handedOver })
        #expect(runner.shift.beds.allSatisfy { $0 == nil })
        let ends = runner.drainEvents().filter { $0 == .shiftEnded }
        #expect(ends.count == 1)
        #expect(throws: ShiftActionError.shiftOver) {
            try runner.perform(.examine(patient: 1))
        }
    }

    @Test("An auto-player can play a whole shift in real time")
    func autoPlay() {
        var runner = ShiftRunner(
            shift: Shift(config: ShiftConfig(seed: 3, duration: 120)),
            autoPlayer: AutoPlayer(style: .expert, seed: 3)
        )
        #expect(runner.isAutoPlaying)
        var frames = 0
        while !runner.shift.isOver && frames < 20_000 {
            runner.frame(seconds: 1.0 / 60)
            frames += 1
        }
        #expect(runner.shift.isOver)
        #expect(runner.shift.report.discharged >= 1)
        #expect(runner.shift.xpEarned > 0)
    }

    @Test("Auto-play replays identically from the same seed")
    func autoPlayReplay() {
        func play() -> Shift {
            var runner = ShiftRunner(
                shift: Shift(config: ShiftConfig(seed: 9, duration: 90)),
                timeScale: 4,
                autoPlayer: AutoPlayer(style: .average, seed: 9)
            )
            while !runner.shift.isOver { runner.frame(seconds: 1.0 / 30) }
            return runner.shift
        }
        #expect(play() == play())
    }
}
