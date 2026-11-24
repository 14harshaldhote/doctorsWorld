class_name Lives
extends RefCounted
## Staff lives (stage 26, story/arcs.json). Every colleague runs on a few
## needs (rest, money, family, pride, ambition) that drift from day to day,
## and has a goal of their own. On a day with room for it, the colleague
## whose need is loudest walks up to the doctor on Ward 4 and asks for
## something (the conversation is in story/lives.json, played by the ward).
## What the doctor says sets a story flag and moves trust; some days later
## a message says how it went, and the breathers remember it too
## (Feelings, "if").
##
## Needs and scores are worked out again from the career's hospital seed
## and the day, so nothing about them is stored. What is stored, in the
## counters (and so in the morning snapshot): "lv_<arc>" is the day the
## colleague asked (0: not yet) and "lv_last" the last day anyone did.
## Scoring is a handful of multiplications: it costs nothing to run.

const PREFIX := "lv_"
## The doctor's own counter of the last day a colleague asked.
const LAST := "lv_last"


static func data() -> Dictionary:
	return StoryBook.chapter("arcs")


static func arcs() -> Dictionary:
	return data().get("arcs", {})


static func arc(id: String) -> Dictionary:
	return arcs().get(id, {})


static func ids() -> Array:
	var found := arcs().keys()
	found.sort()
	return found


## The story's stretch a day falls in ("junior", ... "chief"), or "".
static func chapter_of(day: int) -> String:
	var chapters: Dictionary = data().get("chapters", {})
	for name: String in chapters:
		var span: Array = chapters[name]
		if day >= int(span[0]) and day <= int(span[1]):
			return name
	return ""


## The last day of the stretch a day falls in (the story jumps ahead after it).
static func chapter_end(day: int) -> int:
	var chapter := chapter_of(day)
	if chapter.is_empty():
		return -1
	return int((data()["chapters"] as Dictionary)[chapter][1])


static func _roll(profile: PlayerProfile, what: String) -> int:
	return absi(("%d|%s" % [ShiftDay.hospital_seed(profile), what]).hash())


## How loud one of a colleague's needs is today, 0 to 100: their own
## nature, drifting up and down every few days.
static func need(profile: PlayerProfile, who: String, need_name: String, day: int) -> float:
	var base := float(((data().get("people", {}) as Dictionary).get(who, {}) as Dictionary).get(need_name, 50))
	var drift := float(_roll(profile, "need|%s|%s|%d" % [who, need_name, day / 3]) % 31) - 15.0
	return clampf(base + drift, 0.0, 100.0)


## How much a colleague wants to ask today: their needs as the arc weighs
## them, a little more from someone who trusts the doctor, and the day's luck.
static func score(profile: PlayerProfile, id: String, day: int) -> float:
	var entry := arc(id)
	var who := str(entry.get("who", ""))
	var total := 0.0
	var weights: Dictionary = entry.get("needs", {})
	for need_name: String in weights:
		total += float(weights[need_name]) * need(profile, who, need_name, day) / 100.0
	total += float(profile.trust(who) - 50) / 250.0
	total += float(_roll(profile, "luck|%s|%d" % [id, day]) % 100) / 400.0
	return total


## The day a colleague asked (0: not yet).
static func asked_on(profile: PlayerProfile, id: String) -> int:
	return profile.count(PREFIX + id)


## True when an arc could start today: not asked yet, its day has come,
## its colleague is in this stretch of the story, there's time for its
## ending before the story jumps ahead, and nobody asked in the last few days.
static func can_start(profile: PlayerProfile, id: String, day: int) -> bool:
	var entry := arc(id)
	if entry.is_empty() or asked_on(profile, id) > 0:
		return false
	if day < int(data().get("first_day", 9)) or day < int(entry.get("from_day", 0)):
		return false
	if chapter_of(day) not in (entry.get("chapters", []) as Array):
		return false
	var after: Array = entry.get("after", [1, 2])
	if day + int(after[1]) > chapter_end(day):
		return false
	var last := profile.count(LAST)
	return last <= 0 or day - last >= int(data().get("gap_days", 2))


## Who asks today: the arc whose colleague wants it most, if they want it
## enough, or "" (most days nobody does).
static func today(profile: PlayerProfile) -> String:
	var day := profile.day
	var best := ""
	var best_score := float(data().get("threshold", 0.6))
	for id: String in ids():
		if not can_start(profile, id, day):
			continue
		var value := score(profile, id, day)
		if value >= best_score:
			best = id
			best_score = value
	return best


## The colleague an arc is about.
static func who(id: String) -> String:
	return str(arc(id).get("who", ""))


## The conversation an arc plays.
static func talk(id: String) -> String:
	return str(arc(id).get("talk", ""))


## The arc a conversation belongs to, or "".
static func arc_for_talk(key: String) -> String:
	for id: String in ids():
		if talk(id) == key:
			return id
	return ""


## The colleague asked today.
static func asked(profile: PlayerProfile, id: String) -> void:
	profile.set_count(PREFIX + id, profile.day)
	profile.set_count(LAST, profile.day)
	PhoneBook.forget()


## The day the message about how it went arrives: never before the evening
## of the party the arc invited the doctor to (Life), if it has one.
static func payoff_day(profile: PlayerProfile, id: String) -> int:
	var after: Array = arc(id).get("after", [1, 2])
	var low := int(after[0])
	var spread := maxi(1, int(after[1]) - low + 1)
	var day := asked_on(profile, id) + low + _roll(profile, "payoff|" + id) % spread
	return maxi(day, Life.reception_day(profile, id) + 1)


## How it went, in the colleague's words, for what the doctor said ("" when
## nothing they said is remembered).
static func payoff_text(profile: PlayerProfile, id: String) -> String:
	for entry: Dictionary in arc(id).get("payoff", []):
		if Feelings.holds(profile.flags, str(entry.get("if", ""))):
			return str(entry.get("text", ""))
	return ""


## The messages about how things went, for the phone's last few days.
static func items(profile: PlayerProfile) -> Array:
	var found := []
	var first := maxi(1, profile.day - PhoneBook.WINDOW + 1)
	for id: String in ids():
		if asked_on(profile, id) <= 0:
			continue
		var day := payoff_day(profile, id)
		var text := payoff_text(profile, id)
		if day < first or day > profile.day or text.is_empty():
			continue
		var at := 19 * 60 + 30 + _roll(profile, "at|" + id) % 120
		var from := who(id)
		found.append({"id": PREFIX + id, "kind": "chat", "chat": from, "from": from, "text": text, "photo": "",
			"caption": "", "deleted": false, "reply": [], "day": day, "at": at, "stamp": PhoneBook.stamp(day, at)})
	return found
