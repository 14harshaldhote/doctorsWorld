class_name Life
extends RefCounted
## The doctor's life outside the wards (stage 27, story/life.json). After
## every day on Ward 4 that isn't a night shift there is an evening: chai in
## the canteen with whoever is on late, the hostel room, a video call home,
## food, and bed. Some evenings are parties, with a game.
##
## It all comes back to the hospital:
##   sleep    when the doctor goes to bed (and whether they ate) decides how
##            much they slept; too little and their hands shake in theatre
##            the next day (tremor(), read by the operation)
##   home     nobody calling home for a few days brings Mum's messages, then
##            Mum herself, up to Ward 4 with rajma (mum_due())
##   chai     a colleague's tip for tomorrow, said over chai and shown again
##            in the morning, and a little trust
##   parties  trust with everyone there, XP, a game to win or lose, and a
##            pager that goes off at the worst moment; skipping one costs a
##            little trust with the people who were there
##
## Everything is kept in the profile's counters (so in the morning snapshot):
## see the names below. Nothing here runs per frame.

## The bedtime of the last evening, in minutes from the evening's midnight
## (past 24 * 60 after midnight), and the morning it counts for.
const BED := "life_bed"
const BED_DAY := "life_bed_day"
## 1 if the doctor ate that evening.
const ATE := "life_ate"
## The last day the doctor called home, and the day Mum came to the ward.
const CALLED := "life_called"
const MUM := "life_mum"
## How many calls home there have been (the calls take turns).
const CALLS := "life_calls"
## The last finished day that had its evening (so it is never played twice),
## and the first (home counts from there: a career from before evenings
## existed isn't owed any calls).
const DONE := "life_evening"
const FIRST := "life_first"
## The finished day whose evening is waiting (set as the day closes, so a
## save from before evenings existed, or a day restarted from the title, is
## never owed one), and when the doctor left the ward that day.
const DUE := "life_due"
const LEFT := "life_left"
## The tip for the morning: the day it is for, and who said which one
## (TIPPERS index * 10 + the tip's index).
const TIP_DAY := "life_tip_day"
const TIP := "life_tip"
## Chats over chai with each colleague so far: "life_chai_<id>".
const CHAI := "life_chai_"
## A party's outcome: "life_party_<id>" is the day it was had (negative:
## the day it was skipped).
const PARTY := "life_party_"
## The days Mum texted to ask for a call: "life_nag_<day>" is how many days
## it had been.
const NAG := "life_nag_"
## The colleagues who give tips, in a fixed order (for TIP).
const TIPPERS := ["priya", "tom", "grace", "khan", "sethi", "zoya", "neha", "iyer", "saxena"]


static func data() -> Dictionary:
	return StoryBook.chapter("life")


static func rule(key: String, fallback: Variant = 0) -> Variant:
	return data().get(key, fallback)


static func _roll(profile: PlayerProfile, what: String) -> int:
	return absi(("%d|life|%s" % [ShiftDay.hospital_seed(profile), what]).hash())


# --- Which evenings ------------------------------------------------------------------

## True when a finished day has an evening after it: a day on Ward 4 that
## wasn't a night shift.
static func has_evening(day: int) -> bool:
	if day < int(rule("first_day", Ward.FIRST_DAY)):
		return false
	return day != Ward.NIGHT_DAY and day not in WardStory.NIGHTS


## A day on the ward is over (Main closes it): its evening, if it has one,
## is waiting, starting a little after the doctor left.
static func day_closed(profile: PlayerProfile, finished: int, left_at: int) -> void:
	if not has_evening(finished):
		return
	profile.set_count(DUE, finished)
	profile.set_count(LEFT, left_at)


## True when the evening after a finished day is still to come.
static func evening_due(profile: PlayerProfile, finished: int) -> bool:
	return has_evening(finished) and profile.count(DUE) == finished and profile.count(DONE) < finished


## The evening after a finished day is over: bed at that time, having eaten
## or not. Sleep counts for the next morning.
static func go_to_bed(profile: PlayerProfile, finished: int, bed: int, ate: bool) -> void:
	profile.set_count(BED, bed)
	profile.set_count(BED_DAY, finished + 1)
	profile.set_count(ATE, 1 if ate else 0)
	profile.set_count(DONE, maxi(profile.count(DONE), finished))
	if profile.count(FIRST) <= 0:
		profile.set_count(FIRST, finished)


## What kind of day a day is, for tips: "theatre", "night", "review",
## "meeting" or "ward".
static func kind_of(day: int) -> String:
	if day == Ward.NIGHT_DAY or day in WardStory.NIGHTS:
		return "night"
	if Ward.REVIEWS.has(day) and day != 27:
		return "review"
	var line := str(WardStory.DAY_LINES.get(day, ""))
	if line.begins_with("Theatre day"):
		return "theatre"
	if line.begins_with("Meeting day") or line.begins_with("Board day") or line.begins_with("Interview day"):
		return "meeting"
	return "ward"


## When the evening starts: seven, or a little after the doctor left.
static func start_minutes(left_at: int) -> int:
	return maxi(int(rule("start", 19 * 60)), left_at + 15)


# --- Sleep -------------------------------------------------------------------------

## Hours of sleep from a bedtime (minutes after the evening's midnight; past
## midnight is more than 24 * 60), to the alarm. Going to bed hungry costs a
## little.
static func sleep_hours(bed: int, ate: bool) -> float:
	var wake := 24 * 60 + int(rule("wake", 390))
	var hours := float(wake - bed) / 60.0
	if not ate:
		hours -= float(rule("hungry_sleep", 0.5))
	return clampf(hours, 0.0, 12.0)


## How much the doctor slept before today, or -1 when today didn't follow
## an evening (a night shift, the first days, an old save).
static func slept(profile: PlayerProfile) -> float:
	if profile.count(BED_DAY) != profile.day or profile.count(BED) <= 0:
		return -1.0
	return sleep_hours(profile.count(BED), profile.count(ATE) == 1)


## How much the doctor's hands shake today, 0 (steady) to 1 (a bad night):
## nothing above good_sleep hours, everything at worst_sleep or less.
static func tremor(profile: PlayerProfile) -> float:
	var hours := slept(profile)
	if hours < 0.0:
		return 0.0
	var good := float(rule("good_sleep", 6.5))
	var worst := float(rule("worst_sleep", 4.0))
	return clampf((good - hours) / maxf(0.1, good - worst), 0.0, 1.0)


## A line about the night, for the morning.
static func sleep_line(hours: float) -> String:
	for entry: Array in rule("sleep_lines", []):
		if hours >= float(entry[0]):
			return str(entry[1])
	return ""


## "7 h 20 min" of sleep.
static func hours_text(hours: float) -> String:
	var minutes := int(round(hours * 60.0))
	return "%d h %02d min" % [minutes / 60, minutes % 60]


## A bedtime as a clock ("23:40", "01:10").
static func clock(minutes: int) -> String:
	var wrapped := posmod(minutes, 24 * 60)
	return "%02d:%02d" % [wrapped / 60, wrapped % 60]


# --- Home ---------------------------------------------------------------------------

## The doctor called home on the evening after a day.
static func called_home(profile: PlayerProfile, day: int) -> void:
	profile.set_count(CALLED, maxi(profile.count(CALLED), day))
	profile.add_count(CALLS, 1)
	PhoneBook.forget()


## Days since the doctor last called home or saw Mum, counted from the
## first evening (0 before there has been one).
static func days_without_home(profile: PlayerProfile, day: int) -> int:
	var first := profile.count(FIRST)
	if first <= 0:
		return 0
	var last := maxi(maxi(profile.count(CALLED), profile.count(MUM)), first)
	return maxi(0, day - last)


## True when Mum has had enough and comes to the ward today.
static func mum_due(profile: PlayerProfile) -> bool:
	return days_without_home(profile, profile.day) > int(rule("home_every", 4))


## Mum came to the ward today (that counts as seeing her).
static func mum_came(profile: PlayerProfile) -> void:
	profile.set_count(MUM, profile.day)
	PhoneBook.forget()


## True when Mum's been to the ward since the last call home.
static func mum_came_since_call(profile: PlayerProfile) -> bool:
	return profile.count(MUM) > profile.count(CALLED)


## The morning of a day on the ward: Mum texts if it has been a while, and
## what the doctor should hear about last night (how they slept, the tip
## from the evening's chai). Returns the lines for the morning.
static func morning(profile: PlayerProfile) -> Array[String]:
	var lines: Array[String] = []
	var away := days_without_home(profile, profile.day)
	if away >= 2:
		profile.set_count(NAG + str(profile.day), mini(away, 4))
		PhoneBook.forget()
	var hours := slept(profile)
	if hours >= 0.0:
		lines.append("Slept %s. %s" % [hours_text(hours), sleep_line(hours)])
	var tip := morning_tip(profile)
	if not tip.is_empty():
		lines.append(tip)
	return lines


## Mum's messages asking for a call, for the phone.
static func items(profile: PlayerProfile) -> Array:
	var found := []
	var first := maxi(1, profile.day - PhoneBook.WINDOW + 1)
	var texts: Array = rule("mum_texts", [])
	var last := ""
	for day in range(first, profile.day + 1):
		var away := profile.count(NAG + str(day))
		if away < 2:
			last = ""
			continue
		var text := ""
		for entry: Array in texts:
			if away >= int(entry[0]):
				text = str(entry[1])
		# Each message once a stretch: Mum doesn't repeat herself. She escalates.
		if text.is_empty() or text == last:
			continue
		last = text
		var at := 13 * 60 + 10 + _roll(profile, "nag|%d" % day) % 50
		found.append({"id": "%s%d" % [NAG, day], "kind": "chat", "chat": "mum", "from": "mum", "text": text, "photo": "",
			"caption": "", "deleted": false, "reply": [], "day": day, "at": at, "stamp": PhoneBook.stamp(day, at)})
	return found


## Which call home it is tonight: the first whose reason holds (a patient
## lost today, a promotion, Mum's visit, the very first call), or the next of
## the ordinary ones in turn.
static func call_for(profile: PlayerProfile, day: int) -> Dictionary:
	var ordinary: Array = []
	for entry: Dictionary in rule("calls", []):
		var reason := str(entry.get("if", ""))
		if reason.is_empty():
			ordinary.append(entry)
		elif _reason(profile, reason, day):
			return entry
	if ordinary.is_empty():
		return {}
	return ordinary[(profile.count(CALLS) + _roll(profile, "calls") % 3) % ordinary.size()]


static func _reason(profile: PlayerProfile, reason: String, day: int) -> bool:
	match reason:
		"lost_today":
			for entry: Dictionary in profile.wall:
				if int(entry.get("day", -1)) == day:
					return true
			return false
		"promoted_today":
			return Ward.REVIEWS.has(day) and profile.has_flag("ward_day%d" % day)
		"mum_visited":
			return mum_came_since_call(profile)
		"first_call":
			return profile.count(CALLS) == 0
	return false


## Something to eat in the hostel tonight.
static func eat_for(profile: PlayerProfile, day: int) -> Dictionary:
	var eats: Array = rule("eats", [])
	if eats.is_empty():
		return {}
	return eats[_roll(profile, "eat|%d" % day) % eats.size()]


# --- The canteen ---------------------------------------------------------------------

## The two colleagues having chai in the canteen tonight.
static func staff_tonight(profile: PlayerProfile, day: int) -> Array:
	var chapter := Lives.chapter_of(day)
	if chapter.is_empty():
		chapter = "ward"
	var pool: Array = ((rule("staff", {}) as Dictionary).get(chapter, []) as Array).duplicate()
	var chats: Dictionary = rule("chai", {})
	pool = pool.filter(func(id: String) -> bool: return chats.has(id))
	var found := []
	var roll := _roll(profile, "staff|%d" % day)
	while found.size() < 2 and not pool.is_empty():
		var index := roll % pool.size()
		found.append(pool[index])
		pool.remove_at(index)
		roll = roll / 7 + 13
	return found


## Mani's hello tonight.
static func mani_line(profile: PlayerProfile, day: int) -> Dictionary:
	var lines: Array = rule("mani", [])
	return lines[_roll(profile, "mani|%d" % day) % lines.size()] if not lines.is_empty() else {}


## The chat over chai with a colleague: their chats take turns.
static func chai_talk(profile: PlayerProfile, who: String) -> String:
	var talks: Array = (rule("chai", {}) as Dictionary).get(who, [])
	if talks.is_empty():
		return ""
	return str(talks[profile.count(CHAI + who) % talks.size()])


## A colleague's tip for a day: one meant for that kind of day if they have
## one, else their general one. Returns {for, line, short, index}.
static func tip_for(who: String, day: int) -> Dictionary:
	var tips: Array = (rule("tips", {}) as Dictionary).get(who, [])
	if tips.is_empty():
		return {}
	var kind := kind_of(day)
	var fallback := -1
	for index in tips.size():
		var tip: Dictionary = tips[index]
		if str(tip.get("for", "")) == kind:
			return _indexed(tip, index)
		if str(tip.get("for", "")) == "any" and fallback < 0:
			fallback = index
	return _indexed(tips[maxi(0, fallback)], maxi(0, fallback))


static func _indexed(tip: Dictionary, index: int) -> Dictionary:
	var copy := tip.duplicate()
	copy["index"] = index
	return copy


## The doctor had chai with a colleague after a day: a chat had, and their
## tip remembered for the morning.
static func had_chai(profile: PlayerProfile, who: String, finished: int) -> void:
	profile.add_count(CHAI + who, 1)
	var tip := tip_for(who, finished + 1)
	if tip.is_empty() or who not in TIPPERS:
		return
	profile.set_count(TIP_DAY, finished + 1)
	profile.set_count(TIP, TIPPERS.find(who) * 10 + int(tip["index"]))


## This morning's tip from last night's chai, or "".
static func morning_tip(profile: PlayerProfile) -> String:
	if profile.count(TIP_DAY) != profile.day:
		return ""
	var code := profile.count(TIP)
	var who: String = TIPPERS[clampi(code / 10, 0, TIPPERS.size() - 1)]
	var tips: Array = (rule("tips", {}) as Dictionary).get(who, [])
	if tips.is_empty():
		return ""
	var tip: Dictionary = tips[clampi(code % 10, 0, tips.size() - 1)]
	return "%s's tip: %s" % [short_name(who), str(tip.get("short", ""))]


## How the doctor would name someone in a line: "Priya", "Dr. Iyer", "Sister Grace".
static func short_name(who: String) -> String:
	var full := str(StoryBook.cast().get(who, {}).get("name", who.capitalize()))
	var words := full.split(" ")
	if full.begins_with("Dr. "):
		return "%s %s" % [words[0], words[words.size() - 1]]
	if full.begins_with("Sister "):
		# Sister Grace, never Sister Mathew.
		return "%s %s" % [words[0], words[1]]
	return words[0]


# --- Parties ------------------------------------------------------------------------

static func parties() -> Dictionary:
	return rule("parties", {})


static func party(id: String) -> Dictionary:
	return parties().get(id, {})


## The party on the evening after a day, or "": a fixed one (hostel night,
## Diwali...), else Dr. Khan's reception after she has asked, else one of
## the Chief's regular ones every few days.
static func party_on(profile: PlayerProfile, day: int) -> String:
	if not has_evening(day):
		return ""
	for id: String in parties():
		if int(party(id).get("day", -1)) == day:
			return id
	for id: String in parties():
		var arc := str(party(id).get("arc", ""))
		if not arc.is_empty() and reception_day(profile, arc) == day:
			return id
	var repeat: Dictionary = rule("repeat", {})
	var from := int(repeat.get("from", 1000000))
	var every := maxi(1, int(repeat.get("every", 7)))
	var list: Array = repeat.get("parties", [])
	if day >= from and (day - from) % every == 0 and not list.is_empty():
		return str(list[((day - from) / every) % list.size()])
	return ""


## The evening of the party a colleague's arc invited the doctor to: the
## first evening after they asked that has no other party, or -1.
static func reception_day(profile: PlayerProfile, arc: String) -> int:
	var asked := Lives.asked_on(profile, arc)
	if asked <= 0 or party_for_arc(arc).is_empty():
		return -1
	var day := asked + 1
	var fixed := {}
	for id: String in parties():
		if party(id).has("day"):
			fixed[int(party(id)["day"])] = true
	while day <= asked + 3:
		if has_evening(day) and not fixed.has(day):
			return day
		day += 1
	return -1


## The party a colleague's arc invites the doctor to, or "".
static func party_for_arc(arc: String) -> String:
	for id: String in parties():
		if str(party(id).get("arc", "")) == arc:
			return id
	return ""


## The flag a party's game leaves: "<talk>_won", or for a speech
## "<talk>_great", "_ok" or "_flop".
static func result_flag(id: String, result: String) -> String:
	return "%s_%s" % [str(party(id).get("talk", id)), result]


## The doctor went to a party after a day: trust with everyone there, its
## XP, and bed at its time (later or earlier if the pager took them away).
## Returns the bedtime.
static func went(profile: PlayerProfile, id: String, finished: int) -> int:
	var entry := party(id)
	profile.set_count(PARTY + id, finished)
	for who: String in entry.get("guests", []):
		if StoryBook.cast().get(who, {}).has("trust"):
			profile.change_trust(who, 2, int(StoryBook.cast()[who].get("trust", 50)))
	profile.total_xp += int(entry.get("xp", 0))
	var left := str(entry.get("left", ""))
	if not left.is_empty() and profile.has_flag(left):
		return int(entry.get("left_bed", entry.get("bed", 23 * 60)))
	return int(entry.get("bed", 23 * 60))


## The doctor skipped a party: the people there notice, a little.
static func skipped(profile: PlayerProfile, id: String, finished: int) -> void:
	var entry := party(id)
	profile.set_count(PARTY + id, -finished)
	for who: String in entry.get("guests", []):
		if StoryBook.cast().get(who, {}).has("trust"):
			profile.change_trust(who, -1, int(StoryBook.cast()[who].get("trust", 50)))
	var missed := str(entry.get("missed", ""))
	if not missed.is_empty():
		profile.set_flag(missed)


## A speech's verdict from its points: "great", "ok" or "flop".
static func speech_verdict(speech: Dictionary, points: int) -> String:
	if points >= int(speech.get("great", 99)):
		return "great"
	if points >= int(speech.get("ok", 99)):
		return "ok"
	return "flop"
