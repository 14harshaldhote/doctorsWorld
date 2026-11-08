import Testing
@testable import GameCore

@Suite("SeededRandom")
struct SeededRandomTests {
    @Test("Matches the SplitMix64 reference sequence")
    func matchesReferenceSequence() {
        var rng = SeededRandom(seed: 1_234_567)
        #expect(rng.next() == 6_457_827_717_110_365_317)
        #expect(rng.next() == 3_203_168_211_198_807_973)
        #expect(rng.next() == 9_817_491_932_198_370_423)
    }

    @Test("The same seed always gives the same sequence")
    func sameSeedSameSequence() {
        var first = SeededRandom(seed: 42)
        var second = SeededRandom(seed: 42)
        for _ in 0..<1_000 {
            #expect(first.next() == second.next())
        }
        #expect(first == second)
    }

    @Test("Different seeds give different sequences")
    func differentSeedsDiffer() {
        var first = SeededRandom(seed: 1)
        var second = SeededRandom(seed: 2)
        let a = (0..<8).map { _ in first.next() }
        let b = (0..<8).map { _ in second.next() }
        #expect(a != b)
    }

    @Test("nextInt stays inside its bound", arguments: [1, 2, 3, 7, 100, 1_000_000])
    func nextIntStaysInBound(upperBound: Int) {
        var rng = SeededRandom(seed: UInt64(upperBound))
        for _ in 0..<2_000 {
            let value = rng.nextInt(upperBound: upperBound)
            #expect(value >= 0 && value < upperBound)
        }
    }

    @Test("nextInt(in:) covers every value of a small range")
    func nextIntInRangeCoversRange() {
        var rng = SeededRandom(seed: 7)
        var seen = Set<Int>()
        for _ in 0..<500 {
            let value = rng.nextInt(in: -2...3)
            #expect((-2...3).contains(value))
            seen.insert(value)
        }
        #expect(seen == Set(-2...3))
    }

    @Test("nextDouble is in 0 ..< 1 and roughly uniform")
    func nextDoubleIsUniform() {
        var rng = SeededRandom(seed: 99)
        var sum = 0.0
        let count = 10_000
        for _ in 0..<count {
            let value = rng.nextDouble()
            #expect(value >= 0 && value < 1)
            sum += value
        }
        let mean = sum / Double(count)
        #expect(abs(mean - 0.5) < 0.02)
    }

    @Test("chance respects its edges")
    func chanceEdges() {
        var rng = SeededRandom(seed: 5)
        for _ in 0..<200 {
            #expect(rng.chance(0) == false)
            #expect(rng.chance(1) == true)
            #expect(rng.chance(-3) == false)
            #expect(rng.chance(4) == true)
        }
    }

    @Test("pick returns nil for empty input and a member otherwise")
    func pickElements() {
        var rng = SeededRandom(seed: 11)
        let empty: [String] = []
        #expect(rng.pick(from: empty) == nil)
        let beds = ["A", "B", "C"]
        for _ in 0..<100 {
            let bed = rng.pick(from: beds) ?? "none"
            #expect(beds.contains(bed))
        }
    }

    @Test("Keeps its seed while the state advances")
    func keepsSeed() {
        var rng = SeededRandom(seed: 3)
        _ = rng.next()
        #expect(rng.seed == 3)
        #expect(rng.state != 3)
    }
}
