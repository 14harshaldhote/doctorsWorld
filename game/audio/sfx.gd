class_name Sfx
extends RefCounted
## Sound effects made in code: applause, a knock at the door, an ambulance
## siren, the pager, button taps, a chime for a job well done, a buzz for a
## mistake, the monitor's beep, gas hissing into a keyhole port and a
## level-up flourish, the phone ringing and pinging, a goat that wandered
## into casualty, and a wedding band of a ringtone. No sound files to ship
## or license. Effects play on the Effects bus, so the Sound effects
## setting controls them.

const NAMES := ["applause", "knock", "siren", "pager", "tap", "chime", "buzz", "beep", "hiss", "levelup", "ring", "message",
	"bleat", "ringtone"]

## A node that outlives screen changes (Main), for sounds like button taps
## that should keep playing when the screen that made them goes away.
static var host: Node
static var _cache := {}


static func stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = Voice.to_stream(_samples(sound), 0.6)
	return _cache[sound]


## Plays a sound once on a node. Returns the player, or null when sound is off.
static func play(parent: Node, sound: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not Voice.enabled or parent == null or not parent.is_inside_tree() or GameSettings.current.effects <= 0.0:
		return null
	GameSettings.ensure_buses()
	var player := AudioStreamPlayer.new()
	player.name = "Sfx"
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.bus = &"Effects"
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Plays a sound on the host (when there is one), for interface sounds.
static func ui(sound: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if host == null or not is_instance_valid(host):
		return null
	return play(host, sound, volume_db)


static func _tone(out: PackedFloat32Array, at: int, frequency: float, seconds: float, level: float, decay: float,
		harmonics: int = 3) -> void:
	var rate := float(Voice.RATE)
	for index in mini(int(rate * seconds), out.size() - at):
		var time := index / rate
		var value := 0.0
		for harmonic in harmonics:
			value += sin(TAU * frequency * (harmonic + 1) * time) / pow(harmonic + 1, 1.6)
		out[at + index] += value * level * exp(-time * decay) * minf(1.0, time * 400.0)


static func _samples(sound: String) -> PackedFloat32Array:
	var rate := float(Voice.RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var out := PackedFloat32Array()
	match sound:
		"applause":
			out.resize(int(rate * 3.2))
			for clap in 520:
				# Claps are densest in the middle and thin out at the end.
				var at := int(pow(rng.randf(), 1.25) * (out.size() - 800))
				var loudness := rng.randf_range(0.4, 1.0)
				var low := 0.0
				for index in 600:
					var noise := rng.randf_range(-1.0, 1.0)
					low = low * 0.55 + noise * 0.45
					out[at + index] += (noise - low * 0.6) * loudness * exp(-index / 70.0)
		"knock":
			out.resize(int(rate * 0.8))
			for knock in 3:
				var at := int(rate * (0.04 + knock * 0.21))
				for index in int(rate * 0.12):
					var time := index / rate
					out[at + index] += (sin(TAU * 115.0 * time) + rng.randf_range(-0.3, 0.3)) * exp(-time * 38.0)
		"siren":
			out.resize(int(rate * 3.4))
			var phase := 0.0
			for index in out.size():
				var time := index / rate
				var frequency := 960.0 if int(time / 0.42) % 2 == 0 else 770.0
				phase += TAU * frequency / rate
				var fade := minf(1.0, time / 0.6) * minf(1.0, (3.4 - time) / 0.8)
				out[index] = (sin(phase) + sin(phase * 3.0) * 0.25) * fade
		"pager":
			out.resize(int(rate * 0.6))
			for beep in 3:
				var at := int(rate * beep * 0.17)
				for index in int(rate * 0.1):
					var time := index / rate
					out[at + index] += signf(sin(TAU * 2100.0 * time)) * 0.5 * minf(1.0, (0.1 - time) * 60.0)
		"tap":
			out.resize(int(rate * 0.06))
			for index in out.size():
				var time := index / rate
				out[index] = (sin(TAU * 1650.0 * time) * 0.7 + rng.randf_range(-0.3, 0.3)) * exp(-time * 90.0)
		"chime":
			out.resize(int(rate * 1.1))
			_tone(out, 0, 1318.5, 1.1, 0.8, 5.0)
			_tone(out, int(rate * 0.11), 1975.5, 1.0, 0.7, 4.5)
		"buzz":
			out.resize(int(rate * 0.5))
			for index in out.size():
				var time := index / rate
				var frequency := 220.0 if time < 0.2 else 175.0
				var square := signf(sin(TAU * frequency * time)) * 0.35 + sin(TAU * frequency * time) * 0.4
				out[index] = square * minf(1.0, (0.5 - time) * 20.0) * minf(1.0, time * 200.0)
		"beep":
			out.resize(int(rate * 0.12))
			for index in out.size():
				var time := index / rate
				out[index] = sin(TAU * 980.0 * time) * minf(1.0, time * 300.0) * minf(1.0, (0.12 - time) * 120.0)
		"hiss":
			# Soft, breathy noise that fades in and out, so repeats blend.
			out.resize(int(rate * 0.5))
			var low := 0.0
			for index in out.size():
				var time := index / rate
				var noise := rng.randf_range(-1.0, 1.0)
				low = low * 0.7 + noise * 0.3
				out[index] = (noise - low) * 0.5 * sin(PI * time / 0.5)
		"levelup":
			out.resize(int(rate * 1.3))
			for step in 4:
				_tone(out, int(rate * step * 0.09), [1046.5, 1318.5, 1568.0, 2093.0][step], 1.0, 0.6, 4.0)
		"ring":
			# A soft marimba ring: two runs of notes, then a rest before the
			# next ring.
			out.resize(int(rate * 1.6))
			for run in 2:
				for note in 4:
					_tone(out, int(rate * (run * 0.6 + note * 0.11)), [1174.7, 1480.0, 1174.7, 1760.0][note], 0.45, 0.45, 9.0, 2)
		"message":
			out.resize(int(rate * 0.5))
			_tone(out, 0, 1568.0, 0.4, 0.45, 10.0, 2)
			_tone(out, int(rate * 0.09), 2349.3, 0.4, 0.4, 9.0, 2)
		"bleat":
			# Meh-eh-eh: a reedy voice that wobbles in pitch and loudness,
			# rounded at the start (the "m") and trailing off.
			out.resize(int(rate * 0.95))
			var phase := 0.0
			for index in out.size():
				var time := index / rate
				var frequency := 300.0 + 26.0 * time + 34.0 * sin(TAU * 6.5 * time)
				phase += TAU * frequency / rate
				var value := 0.0
				for harmonic in 7:
					value += sin(phase * (harmonic + 1)) / (harmonic + 1) * (1.4 if harmonic in [2, 3] else 1.0)
				var trill := 0.62 + 0.38 * sin(TAU * 12.0 * time)
				var shape := minf(1.0, time / 0.07) * pow(maxf(0.0, 1.0 - time / 0.95), 0.7)
				out[index] = value * 0.32 * trill * shape
		"ringtone":
			# A wedding band on a phone's speaker: a bright reedy tune over a
			# dhol, twice round.
			out.resize(int(rate * 2.6))
			var tune := [523.3, 587.3, 659.3, 784.0, 659.3, 587.3, 523.3, 587.3, 659.3, 784.0, 880.0, 784.0]
			for step in tune.size():
				_tone(out, int(rate * step * 0.18), tune[step], 0.2, 0.34, 6.0, 6)
				_tone(out, int(rate * step * 0.18), tune[step] * 1.5, 0.18, 0.08, 9.0, 2)
			for hit in 9:
				var at := int(rate * hit * 0.27)
				var low := hit % 2 == 0
				for index in mini(int(rate * 0.18), out.size() - at):
					var time := index / rate
					var drum := sin(TAU * (90.0 if low else 180.0) * time * (1.0 + 0.6 * exp(-time * 30.0)))
					out[at + index] += (drum * 0.55 + rng.randf_range(-0.15, 0.15)) * exp(-time * (14.0 if low else 26.0))
		_:
			push_error("Unknown sound: %s" % sound)
			out.resize(1)
	return out
