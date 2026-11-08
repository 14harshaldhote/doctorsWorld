/// A small, fast, deterministic random number generator (SplitMix64).
///
/// Every random choice in the game goes through this type, never through
/// `SystemRandomNumberGenerator`. The same seed therefore always produces the
/// same shift, which makes bugs reproducible and tests exact.
///
/// The helpers below (`nextInt`, `nextDouble`, `chance`) are implemented here
/// rather than relying on the standard library's `random(in:using:)`, whose
/// algorithm is not guaranteed to stay the same across Swift versions.
public struct SeededRandom: RandomNumberGenerator, Sendable, Equatable {
    /// The seed this generator started from.
    public let seed: UInt64
    /// Internal state; advances by a fixed constant on every draw.
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.seed = seed
        self.state = seed
    }

    /// Returns the next 64 random bits.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// A random integer in `0..<upperBound`. `upperBound` must be positive.
    public mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let product = next().multipliedFullWidth(by: UInt64(upperBound))
        return Int(product.high)
    }

    /// A random integer in the closed range.
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + nextInt(upperBound: range.upperBound - range.lowerBound + 1)
    }

    /// A random `Double` in `0 ..< 1` with 53 bits of precision.
    public mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// Returns `true` with the given probability (clamped to `0...1`).
    public mutating func chance(_ probability: Double) -> Bool {
        nextDouble() < min(max(probability, 0), 1)
    }

    /// A random element of a non-empty collection, or `nil` if it is empty.
    public mutating func pick<C: Collection>(from items: C) -> C.Element? {
        guard !items.isEmpty else { return nil }
        let offset = nextInt(upperBound: items.count)
        return items[items.index(items.startIndex, offsetBy: offset)]
    }
}
