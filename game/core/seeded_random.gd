class_name SeededRandom
extends RefCounted
## A small, fast, deterministic random number generator (SplitMix64).
##
## Every random choice in the game goes through this class, never through
## randf() or randi(). The same seed always gives the same results on every
## device, which makes bugs reproducible and tests exact.
##
## GDScript integers are signed 64-bit and wrap on overflow, so the unsigned
## arithmetic of SplitMix64 is done with logical shifts and masks below.

const _GOLDEN := -7046029254386353131  # 0x9E3779B97F4A7C15
const _MIX_1 := -4658895280553007687  # 0xBF58476D1CE4E5B9
const _MIX_2 := -7723592293110705685  # 0x94D049BB133111EB
const _LOW_32 := 0xFFFFFFFF
## Largest bound next_int() accepts. Keeps the high-word maths inside 63 bits.
const MAX_BOUND := 1 << 30

## The seed this generator started from.
var initial_seed: int
## Internal state; advances by a fixed constant on every draw.
var state: int


func _init(start_seed: int = 0) -> void:
	initial_seed = start_seed
	state = start_seed


## Logical (unsigned) right shift of a 64-bit value.
static func shift_right(value: int, bits: int) -> int:
	if bits <= 0:
		return value
	return (value >> bits) & ((1 << (64 - bits)) - 1)


## The next 64 random bits, as a signed int with the same bit pattern.
func next() -> int:
	state += _GOLDEN
	var mixed := state
	mixed = (mixed ^ shift_right(mixed, 30)) * _MIX_1
	mixed = (mixed ^ shift_right(mixed, 27)) * _MIX_2
	return mixed ^ shift_right(mixed, 31)


## A random integer in 0 ..< upper_bound (upper_bound from 1 to MAX_BOUND).
## Uses the high 64 bits of a 64x64 multiply, like the Swift version did.
func next_int(upper_bound: int) -> int:
	assert(upper_bound > 0 and upper_bound <= MAX_BOUND, "upper_bound out of range")
	var bits := next()
	var high := shift_right(bits, 32)
	var low := bits & _LOW_32
	var carry := shift_right(low * upper_bound, 32)
	return shift_right(high * upper_bound + carry, 32)


## A random integer in the closed range low ... high.
func next_int_in(low: int, high: int) -> int:
	return low + next_int(high - low + 1)


## A random float in 0 ..< 1 with 53 bits of precision.
func next_float() -> float:
	return float(shift_right(next(), 11)) / 9007199254740992.0


## True with the given probability (clamped to 0 ... 1).
func chance(probability: float) -> bool:
	return next_float() < clampf(probability, 0.0, 1.0)


## A random element of a non-empty array, or null if it is empty.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[next_int(items.size())]


## A shuffled copy of the array (Fisher-Yates), fully determined by the seed.
func shuffled(items: Array) -> Array:
	var result := items.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var other := next_int(index + 1)
		var held: Variant = result[index]
		result[index] = result[other]
		result[other] = held
	return result
