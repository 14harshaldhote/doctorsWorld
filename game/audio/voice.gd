class_name Voice
extends RefCounted
## Characters speak in short murmured syllables instead of full voice acting,
## with subtitles carrying the words. Each vowel has its own sound, made in
## code at start-up; characters differ by pitch.

const RATE := 22050
const LENGTH := 0.1
const BASE := 150.0
## The two strongest resonances of each vowel, in Hz.
const FORMANTS := {
	"a": Vector2(780, 1250), "e": Vector2(470, 1900), "i": Vector2(320, 2250),
	"o": Vector2(520, 920), "u": Vector2(360, 820),
}

## Turns every game sound on or off (the player's Sound setting).
static var enabled := true
static var _cache := {}


static func vowel_of(letter: String) -> String:
	var lower := letter.to_lower()
	if lower in ["a", "e", "i", "o", "u"]:
		return lower
	return "i" if lower == "y" else "a"


## The murmur for one syllable, by its vowel.
static func syllable(letter: String) -> AudioStreamWAV:
	var vowel := vowel_of(letter)
	if _cache.has(vowel):
		return _cache[vowel]
	var formant: Vector2 = FORMANTS[vowel]
	var weights := PackedFloat32Array()
	for harmonic in range(1, 17):
		var frequency := BASE * harmonic
		weights.append(exp(-pow((frequency - formant.x) / 170.0, 2.0)) +
			0.7 * exp(-pow((frequency - formant.y) / 240.0, 2.0)) + 0.25 / harmonic)
	var count := int(RATE * LENGTH)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for index in count:
		var time := float(index) / RATE
		phase += TAU * BASE * (1.04 - 0.1 * time / LENGTH) / RATE
		var value := 0.0
		for harmonic in weights.size():
			value += weights[harmonic] * sin(phase * (harmonic + 1))
		samples[index] = value * minf(1.0, time / 0.012) * exp(-maxf(0.0, time - 0.03) * 28.0)
	var stream := to_stream(samples, 0.55)
	_cache[vowel] = stream
	return stream


## Packs samples (any loudness) into a 16-bit sound, scaled to a peak level.
static func to_stream(samples: PackedFloat32Array, peak_level: float) -> AudioStreamWAV:
	var peak := 0.0001
	for value in samples:
		peak = maxf(peak, absf(value))
	var gain := peak_level / peak * 32767.0
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		bytes.encode_s16(index * 2, clampi(int(samples[index] * gain), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
