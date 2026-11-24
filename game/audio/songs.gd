class_name Songs
extends RefCounted
## The sarcastic songs (stage 26, story/songs.json): the night nurses'
## song, the canteen's dal jingle and Riverside FM's roast, and the radio's
## requests. A song is music (assets/music/<track>.ogg, made by
## tools/make_music.py to the same tempo and bars) and lines half sung, half
## chanted in each singer's recorded voice, one every few bars. SongPlayer
## plays one; LyricsBanner shows the words.


static func data() -> Dictionary:
	return StoryBook.chapter("songs")


static func songs() -> Dictionary:
	return data().get("songs", {})


static func song(id: String) -> Dictionary:
	return songs().get(id, {})


static func ids() -> Array:
	return songs().keys()


static func station() -> Dictionary:
	return data().get("station", {})


static func lines(id: String) -> Array:
	return song(id).get("lines", [])


## Seconds in one bar of four beats.
static func bar_seconds(id: String) -> float:
	return 4.0 * 60.0 / maxf(1.0, float(song(id).get("bpm", 96)))


## When a line starts, in seconds from the start of the music.
static func line_start(id: String, index: int) -> float:
	var entry := song(id)
	return (int(entry.get("intro", 2)) + index * int(entry.get("bars_per_line", 2))) * bar_seconds(id)


## How long a line has before the next one starts.
static func line_room(id: String) -> float:
	return int(song(id).get("bars_per_line", 2)) * bar_seconds(id)


## How long the whole song lasts.
static func length(id: String) -> float:
	var entry := song(id)
	var bars := int(entry.get("intro", 2)) + lines(id).size() * int(entry.get("bars_per_line", 2)) + int(entry.get("outro", 2))
	return bars * bar_seconds(id)


static func requests() -> Array:
	return data().get("requests", [])


## Today's request on the radio: the same one all day, a different one
## most days.
static func request_for(profile: PlayerProfile) -> Dictionary:
	var all := requests()
	if all.is_empty():
		return {}
	return all[absi(("request|%d|%d" % [ShiftDay.hospital_seed(profile), profile.day]).hash()) % all.size()]


## Every line sung or said in the songs and requests: [{who, text}].
static func spoken() -> Array:
	var found := []
	for id: String in ids():
		for line: Dictionary in lines(id):
			found.append({"who": str(line.get("say", "")), "text": str(line.get("text", ""))})
	for request: Dictionary in requests():
		found.append({"who": str(request.get("say", "")), "text": str(request.get("text", ""))})
	return found
