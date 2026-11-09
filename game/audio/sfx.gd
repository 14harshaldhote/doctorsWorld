class_name Sfx
extends RefCounted
## Sound effects made in code: applause, a knock at the door, an ambulance
## siren and the pager's beep. No sound files to ship or license.

const NAMES := ["applause", "knock", "siren", "pager"]

static var _cache := {}


static func stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = Voice.to_stream(_samples(sound), 0.6)
	return _cache[sound]


## Plays a sound once on a node. Returns the player, or null when sound is off.
static func play(parent: Node, sound: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not Voice.enabled or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.name = "Sfx"
	player.stream = stream(sound)
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


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
		_:
			push_error("Unknown sound: %s" % sound)
			out.resize(1)
	return out
