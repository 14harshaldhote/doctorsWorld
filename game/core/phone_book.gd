class_name PhoneBook
extends RefCounted
## The doctor's phone (stage 23): who writes, what arrives when, and what
## the doctor has read, answered and picked up.
##
## Everything on the phone is an "item": a chat message, a call, a post in
## the feed, a photo in the camera roll or a lab report. Most are written in
## story/phone.json and arrive on their day at their time, or as the day
## ends if the clock never gets that far; PhoneWriter adds the game's own,
## made from what really happened (Varun's reels, the family's evenings,
## the batch group, a thank-you from someone casualty sent home). Nothing
## leaves the device, and nothing here draws (PhonePanel does).
##
## What the career remembers lives in profile.phone, outside the morning
## snapshot (like a letter that has been read, it stays read when a day is
## played again):
##   "seen"    {key: stamp}: read up to here ("c:<chat>", "feed", "calls",
##             "lab", "photos"; "*" is a floor under all of them, so a career
##             that had no phone before doesn't find a year of messages)
##   "replies" {item id: [pick, stamp]}
##   "calls"   {call id: [state ("a" answered, "d" declined, "m" rang out), stamp, pick]}
##   "kept"    [{id, chat, from, name, text, day, at}]: the game's own
##             messages that depend on a day's live casualty (newest last)
##   "days"    {"<day>": {"lost", "xp", "seen", "right", "lead"}}: what a
##             finished day was like, for the evening's messages
## A stamp is day * 10000 + minutes past that day's midnight.

const PATH := "res://story/phone.json"
const STAMP_DAY := 10000
## The game's own messages are made for this many days back (older ones
## fall off the phone, as on a real one that clears old chats).
const WINDOW := 7
## How many of the day-dependent messages, and day notes, are kept.
const KEPT_MAX := 12
const DAYS_MAX := 8
## The most a chat, the feed and the camera roll show.
const CHAT_SHOWN := 60
const FEED_SHOWN := 30
const PHOTOS_SHOWN := 60
## Limits on what a save may hold here (a saved file is checked against them).
const REPLIES_MAX := 400
const SEEN_MAX := 200
const CALLS_MAX := 100
const TEXT_MAX := 400
## The pages people write with (not chats).
const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_#*:-"

static var _data := {}
static var _cache_key := ""
static var _cache: Array = []
## Bumped by anything that changes what the phone holds.
static var _version := 0


# --- Data -------------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func contacts() -> Dictionary:
	return data().get("contacts", {})


## A person, group or page: {name, short, colour, group, about, handle,
## page}. Someone the game wrote for (a casualty family) carries their own
## name on the item instead.
static func contact(id: String, item: Dictionary = {}) -> Dictionary:
	var found: Dictionary = contacts().get(id, {})
	if found.is_empty():
		var name := str(item.get("name", "")) if not item.is_empty() else ""
		return {"name": name if not name.is_empty() else "Unknown number", "colour": "#B8D6D2"}
	return found


static func contact_name(id: String, item: Dictionary = {}) -> String:
	return str(contact(id, item).get("name", id))


## The name to use in a sentence: "Varun", "Mum", "Dr. Iyer".
static func short_name(id: String, item: Dictionary = {}) -> String:
	var found := contact(id, item)
	return str(found.get("short", found.get("name", id)))


static func is_group(id: String) -> bool:
	return contacts().get(id, {}).has("group")


## Two letters for a round picture: "MU", "VK", "CT".
static func initials(id: String, item: Dictionary = {}) -> String:
	var name := contact_name(id, item).replace("Dr. ", "").replace("Mr. ", "").replace("Mrs. ", "")
	# Words that start with a letter: "Priya (Ward 4)" is "P", "City Med '20" is "CM".
	var words: Array[String] = []
	for word in name.split(" ", false):
		if word.substr(0, 1).to_upper() != word.substr(0, 1).to_lower():
			words.append(word)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].substr(0, 1).to_upper()
	return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()


# --- Time -------------------------------------------------------------------------

static func stamp(day: int, minutes: int) -> int:
	return day * STAMP_DAY + clampi(minutes, 0, STAMP_DAY - 1)


static func now(profile: PlayerProfile) -> int:
	return stamp(profile.day, profile.minutes)


## "21:40" (or "25:30", half past one at night) as minutes past midnight.
static func parse_at(text: Variant) -> int:
	if typeof(text) in [TYPE_INT, TYPE_FLOAT]:
		return int(text)
	var parts := str(text).split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return 0
	return int(parts[0]) * 60 + int(parts[1])


## "09:05" for a stamp's time of day (past midnight wraps round).
static func clock(at_stamp: int) -> String:
	var minutes := (at_stamp % STAMP_DAY) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## "09:05" today, "Yesterday", or "Day 4".
static func when_text(profile: PlayerProfile, at_stamp: int) -> String:
	var day := at_stamp / STAMP_DAY
	if day == profile.day:
		return clock(at_stamp)
	if day == profile.day - 1:
		return "Yesterday"
	return "Day %d" % day


# --- What the career remembers -------------------------------------------------------

## profile.phone, made ready to use.
static func state(profile: PlayerProfile) -> Dictionary:
	var phone := profile.phone
	if not phone.has("seen"):
		# The first time this career meets the phone: what came before today
		# counts as read (a new career starts on Day 1 with nothing behind it).
		phone["seen"] = {"*": stamp(profile.day, 0) if profile.day > 1 else 0}
	for key: String in ["replies", "calls", "days"]:
		if not phone.has(key):
			phone[key] = {}
	if not phone.has("kept"):
		phone["kept"] = []
	return phone


## Checks a phone dictionary from a save, keeping only what could be real:
## the right shapes, sensible numbers, short text and not too much of it.
static func clean(raw: Variant) -> Dictionary:
	var phone := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return phone
	var seen: Variant = raw.get("seen")
	if typeof(seen) == TYPE_DICTIONARY:
		phone["seen"] = {}
		for key: Variant in seen:
			if phone["seen"].size() >= SEEN_MAX:
				break
			if _good_id(key) and typeof(seen[key]) in [TYPE_INT, TYPE_FLOAT] and float(seen[key]) >= 0.0:
				phone["seen"][key] = mini(int(seen[key]), 100000 * STAMP_DAY)
	var replies: Variant = raw.get("replies")
	if typeof(replies) == TYPE_DICTIONARY:
		phone["replies"] = {}
		for id: Variant in replies:
			if phone["replies"].size() >= REPLIES_MAX:
				break
			var entry: Variant = replies[id]
			if _good_id(id) and entry is Array and entry.size() == 2 and typeof(entry[0]) in [TYPE_INT, TYPE_FLOAT] \
					and typeof(entry[1]) in [TYPE_INT, TYPE_FLOAT]:
				phone["replies"][id] = [clampi(int(entry[0]), 0, 3), maxi(0, int(entry[1]))]
	var calls: Variant = raw.get("calls")
	if typeof(calls) == TYPE_DICTIONARY:
		phone["calls"] = {}
		for id: Variant in calls:
			if phone["calls"].size() >= CALLS_MAX:
				break
			var entry: Variant = calls[id]
			if _good_id(id) and entry is Array and entry.size() == 3 and str(entry[0]) in ["a", "d", "m"] \
					and typeof(entry[1]) in [TYPE_INT, TYPE_FLOAT] and typeof(entry[2]) in [TYPE_INT, TYPE_FLOAT]:
				phone["calls"][id] = [str(entry[0]), maxi(0, int(entry[1])), clampi(int(entry[2]), -1, 3)]
	var kept: Variant = raw.get("kept")
	if kept is Array:
		phone["kept"] = []
		for entry: Variant in kept:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var item := {}
			for key: String in ["id", "chat", "from"]:
				item[key] = str(entry.get(key, ""))
			for key: String in ["name", "text"]:
				item[key] = str(entry.get(key, "")).substr(0, TEXT_MAX)
			var day: Variant = entry.get("day")
			var at: Variant = entry.get("at")
			if not (_good_id(item["id"]) and _good_id(item["chat"]) and _good_id(item["from"])) \
					or typeof(day) not in [TYPE_INT, TYPE_FLOAT] or typeof(at) not in [TYPE_INT, TYPE_FLOAT]:
				continue
			item["day"] = clampi(int(day), 1, 100000)
			item["at"] = clampi(int(at), 0, 48 * 60)
			phone["kept"].append(item)
		while phone["kept"].size() > KEPT_MAX:
			phone["kept"].pop_front()
	var days: Variant = raw.get("days")
	if typeof(days) == TYPE_DICTIONARY:
		phone["days"] = {}
		for key: Variant in days:
			var note: Variant = days[key]
			if typeof(key) != TYPE_STRING or not (key as String).is_valid_int() or typeof(note) != TYPE_DICTIONARY:
				continue
			var kept_note := {}
			for field: String in ["xp", "seen", "right", "lead"]:
				var value: Variant = note.get(field, 0)
				kept_note[field] = clampi(int(value), -100000, 100000) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0
			kept_note["lost"] = typeof(note.get("lost")) == TYPE_BOOL and bool(note.get("lost"))
			phone["days"][key] = kept_note
		_trim_days(phone["days"])
	return phone


static func _good_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := value as String
	if text.is_empty() or text.length() > 60:
		return false
	for index in text.length():
		if not ID_CHARS.contains(text[index]):
			return false
	return true


static func _trim_days(days: Dictionary) -> void:
	if days.size() <= DAYS_MAX:
		return
	var keys := days.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for index in keys.size() - DAYS_MAX:
		days.erase(keys[index])


## Forgets what was worked out (after the profile changed under it, in tests).
static func forget() -> void:
	_version += 1
	_cache_key = ""


# --- Conditions -------------------------------------------------------------------

## A story condition ("flag", "!flag", "a&b", "a|b"), plus "rank>=N",
## "r:<id>" (that message was answered), "r:<id>=<pick>" and "c:<id>=a"
## (that call was answered) or "c:<id>=d" (it wasn't, yet or ever).
static func holds(profile: PlayerProfile, test: String) -> bool:
	if test.is_empty():
		return true
	if "|" in test:
		for part in test.split("|"):
			if holds(profile, part):
				return true
		return false
	for part in test.split("&"):
		var negated := part.begins_with("!")
		var token := part.substr(1) if negated else part
		if _token(profile, token) == negated:
			return false
	return true


static func _token(profile: PlayerProfile, token: String) -> bool:
	if token.begins_with("rank>="):
		return profile.rank() >= int(token.substr(6))
	if token.begins_with("r:"):
		var parts := token.substr(2).split("=")
		var reply: Variant = state(profile)["replies"].get(parts[0])
		if reply == null:
			return false
		return parts.size() < 2 or int(reply[0]) == int(parts[1])
	if token.begins_with("c:"):
		var parts := token.substr(2).split("=")
		var record: Variant = state(profile)["calls"].get(parts[0])
		var answered := record != null and str(record[0]) == "a"
		return answered if parts.size() < 2 or parts[1] == "a" else not answered
	return profile.has_flag(token)


## The doctor's name and title in a line.
static func fill(profile: PlayerProfile, text: String) -> String:
	if not "{" in text:
		return text
	return text.format({"name": profile.name, "first": profile.first_name(), "last": profile.last_name(),
		"called": profile.called(), "title": profile.full_title()})


# --- Everything on the phone ----------------------------------------------------------

## Every item this career has, arrived or still to come today, oldest first.
## Worked out at most once a frame.
static func items(profile: PlayerProfile) -> Array:
	var phone := state(profile)
	var key := "%d|%d|%d|%d|%d|%d|%d" % [Engine.get_process_frames(), profile.get_instance_id(), _version, profile.day,
		profile.minutes, profile.flags.size(), profile.rank()]
	if key == _cache_key:
		return _cache
	var found: Array = []
	var source := data()
	var by_id := {}
	for entry: Dictionary in source.get("chats", []):
		by_id[str(entry.get("id", ""))] = entry
	for entry: Dictionary in source.get("chats", []):
		if entry.has("answer_to"):
			_add_answer(profile, phone, entry, by_id, found)
			continue
		if not holds(profile, str(entry.get("when", ""))):
			continue
		var item := _item(profile, entry, "chat")
		found.append(item)
		var reply: Variant = phone["replies"].get(item["id"])
		if reply != null and not (item["reply"] as Array).is_empty():
			# What the doctor said back, as their own bubble.
			var pick := clampi(int(reply[0]), 0, (item["reply"] as Array).size() - 1)
			var said := {"id": item["id"] + "#you", "kind": "chat", "chat": item["chat"], "from": "you",
				"text": fill(profile, str(item["reply"][pick])), "photo": "", "caption": "", "deleted": false,
				"reply": [], "stamp": int(reply[1])}
			_set_stamp(said, int(reply[1]))
			found.append(said)
	for entry: Dictionary in source.get("calls", []):
		if holds(profile, str(entry.get("when", ""))):
			_add_call(profile, phone, entry, found)
	for kind: String in ["feed", "photos", "lab"]:
		for entry: Dictionary in source.get(kind, []):
			if holds(profile, str(entry.get("when", ""))):
				found.append(_item(profile, entry, {"feed": "feed", "photos": "photo", "lab": "lab"}[kind]))
	for entry: Dictionary in phone["kept"]:
		var item := _item(profile, entry, "chat")
		item["name"] = str(entry.get("name", ""))
		found.append(item)
	found.append_array(PhoneWriter.items(profile))
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["stamp"]) < int(b["stamp"]) if int(a["stamp"]) != int(b["stamp"]) else str(a["id"]) < str(b["id"]))
	_cache = found
	_cache_key = key
	return found


## An entry from the data as an item, with every field there.
static func _item(profile: PlayerProfile, entry: Dictionary, kind: String) -> Dictionary:
	var day := int(entry.get("day", 1))
	var at := parse_at(entry.get("at", 0))
	var item := {
		"id": str(entry.get("id", "")),
		"kind": kind,
		"chat": str(entry.get("chat", "")),
		"from": str(entry.get("from", "")),
		"text": fill(profile, str(entry.get("text", ""))),
		"photo": str(entry.get("photo", "")),
		"caption": fill(profile, str(entry.get("caption", ""))),
		"deleted": bool(entry.get("deleted", false)),
		"reply": entry.get("reply", []),
		"day": day,
		"at": at,
		"stamp": stamp(day, at),
	}
	for extra: String in ["likes", "patient", "test", "result", "high", "name"]:
		if entry.has(extra):
			item[extra] = entry[extra]
	return item


static func _set_stamp(item: Dictionary, at_stamp: int) -> void:
	item["stamp"] = at_stamp
	item["day"] = at_stamp / STAMP_DAY
	item["at"] = at_stamp % STAMP_DAY


## A message that comes back after the doctor answers, a little later.
static func _add_answer(profile: PlayerProfile, phone: Dictionary, entry: Dictionary, by_id: Dictionary,
		found: Array) -> void:
	var to := str(entry.get("answer_to", ""))
	var reply: Variant = phone["replies"].get(to)
	if reply == null or not by_id.has(to) or not holds(profile, str(by_id[to].get("when", ""))):
		return
	if entry.has("pick") and int(entry["pick"]) != int(reply[0]):
		return
	if not holds(profile, str(entry.get("when", ""))):
		return
	var item := _item(profile, entry, "chat")
	_set_stamp(item, int(reply[1]) + maxi(1, int(entry.get("delay", 1))))
	found.append(item)


## A call: its line in the call log once it has rung (or the day has gone),
## and the message the caller leaves when nobody answers.
static func _add_call(profile: PlayerProfile, phone: Dictionary, entry: Dictionary, found: Array) -> void:
	var item := _item(profile, entry, "call")
	item["lines"] = entry.get("lines", [])
	item["after"] = entry.get("after", [])
	item["busy"] = bool(entry.get("busy", false))
	var record: Variant = phone["calls"].get(item["id"])
	var state_now := ""
	var when := int(item["stamp"])
	if record != null:
		state_now = str(record[0])
		when = int(record[1])
		item["pick"] = int(record[2])
	elif item["busy"] or int(item["day"]) < profile.day:
		# It rang while the doctor couldn't answer (in theatre, or busy all day).
		state_now = "m"
	else:
		item["state"] = "due"
		found.append(item)
		return
	item["state"] = {"a": "answered", "d": "declined", "m": "missed"}[state_now]
	_set_stamp(item, when)
	found.append(item)
	var left := str(entry.get("missed", ""))
	if state_now != "a" and not left.is_empty():
		var caller := str(entry.get("from", ""))
		var writer := caller
		if is_group(caller):
			writer = str((contacts()[caller]["group"] as Array)[0])
		var message := {"id": item["id"] + "#left", "kind": "chat", "chat": caller, "from": writer,
			"text": fill(profile, left), "photo": "", "caption": "", "deleted": false, "reply": []}
		_set_stamp(message, when + 2)
		found.append(message)


## True once an item is on the phone: its day has passed, or it's today and
## the clock has reached it.
static func has_arrived(profile: PlayerProfile, item: Dictionary) -> bool:
	if str(item.get("state", "")) == "due":
		return false
	var day := int(item["day"])
	return day < profile.day or (day == profile.day and int(item["at"]) <= profile.minutes)


## The items that have arrived, oldest first (kind "" for all of them).
static func arrived(profile: PlayerProfile, kind: String = "") -> Array:
	return items(profile).filter(func(item: Dictionary) -> bool:
		return (kind.is_empty() or item["kind"] == kind) and has_arrived(profile, item))


# --- Chats --------------------------------------------------------------------------

## One chat's messages, oldest first (the last CHAT_SHOWN of them).
static func thread(profile: PlayerProfile, chat: String) -> Array:
	var found := arrived(profile, "chat").filter(func(item: Dictionary) -> bool: return item["chat"] == chat)
	return found.slice(maxi(0, found.size() - CHAT_SHOWN))


## Every chat with something in it, the latest first: [{chat, last, unread, name}].
static func chats(profile: PlayerProfile) -> Array:
	# One pass over the messages for every chat's latest and unread count.
	var latest := {}
	var unread := {}
	for item: Dictionary in arrived(profile, "chat"):
		var chat := str(item["chat"])
		latest[chat] = item
		if item["from"] != "you" and int(item["stamp"]) > seen_stamp(profile, "c:" + chat):
			unread[chat] = int(unread.get(chat, 0)) + 1
	var found: Array = []
	for chat: String in latest:
		var last: Dictionary = latest[chat]
		found.append({"chat": chat, "last": last, "unread": int(unread.get(chat, 0)), "name": contact_name(chat, last)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["last"]["stamp"]) > int(b["last"]["stamp"]))
	return found


## How many messages in a chat haven't been read.
static func unread_in(profile: PlayerProfile, chat: String) -> int:
	var after := seen_stamp(profile, "c:" + chat)
	return arrived(profile, "chat").filter(func(item: Dictionary) -> bool:
		return item["chat"] == chat and item["from"] != "you" and int(item["stamp"]) > after).size()


## The latest message in a chat the doctor can still answer, or {}.
static func pending_reply(profile: PlayerProfile, chat: String) -> Dictionary:
	var found := {}
	for item: Dictionary in thread(profile, chat):
		if (item["reply"] as Array).is_empty():
			continue
		found = {} if state(profile)["replies"].has(item["id"]) else item
	return found


## The doctor answers a message with one of its replies. False if it can't be.
static func answer(profile: PlayerProfile, item_id: String, pick: int) -> bool:
	var phone := state(profile)
	if phone["replies"].has(item_id):
		return false
	for item: Dictionary in arrived(profile, "chat"):
		if item["id"] == item_id and pick >= 0 and pick < (item["reply"] as Array).size():
			phone["replies"][item_id] = [pick, now(profile)]
			forget()
			return true
	return false


# --- Seen and unread ------------------------------------------------------------------

static func seen_stamp(profile: PlayerProfile, key: String) -> int:
	var seen: Dictionary = state(profile)["seen"]
	return maxi(int(seen.get(key, 0)), int(seen.get("*", 0)))


## Everything under key that has arrived counts as read.
static func mark_seen(profile: PlayerProfile, key: String) -> void:
	var seen: Dictionary = state(profile)["seen"]
	var at := now(profile)
	if int(seen.get(key, 0)) < at:
		seen[key] = at
		forget()


## Missed calls not yet looked at.
static func missed_unseen(profile: PlayerProfile) -> int:
	var after := seen_stamp(profile, "calls")
	return arrived(profile, "call").filter(func(item: Dictionary) -> bool:
		return item["state"] == "missed" and int(item["stamp"]) > after).size()


## How many things an app has waiting: "chats", "calls", "feed", "photos", "lab".
static func app_unread(profile: PlayerProfile, app: String, live_lab: Array = []) -> int:
	match app:
		"chats":
			var total := 0
			for entry: Dictionary in chats(profile):
				total += int(entry["unread"])
			return total
		"calls":
			return missed_unseen(profile)
		"feed":
			var after := seen_stamp(profile, "feed")
			return feed(profile).filter(func(item: Dictionary) -> bool: return int(item["stamp"]) > after).size()
		"photos":
			var after := seen_stamp(profile, "photos")
			return photos(profile).filter(func(item: Dictionary) -> bool: return int(item["stamp"]) > after).size()
		"lab":
			var after := seen_stamp(profile, "lab")
			return lab(profile, live_lab).filter(func(item: Dictionary) -> bool: return int(item["stamp"]) > after).size()
	return 0


## The number on the Phone button: unread messages and missed calls.
static func badge(profile: PlayerProfile) -> int:
	return app_unread(profile, "chats") + missed_unseen(profile)


# --- Calls ---------------------------------------------------------------------------

## The call that should ring now, or {}.
static func call_due(profile: PlayerProfile) -> Dictionary:
	for item: Dictionary in items(profile):
		if item["kind"] == "call" and str(item.get("state", "")) == "due" and int(item["day"]) == profile.day \
				and int(item["at"]) <= profile.minutes:
			return item
	return {}


## A call answered ("a", with the reply picked or -1), declined ("d") or
## left to ring out ("m").
static func record_call(profile: PlayerProfile, call_id: String, outcome: String, pick: int = -1) -> void:
	if outcome not in ["a", "d", "m"]:
		return
	state(profile)["calls"][call_id] = [outcome, now(profile), pick]
	forget()


## The call log, newest first.
static func call_log(profile: PlayerProfile) -> Array:
	var found := arrived(profile, "call")
	found.reverse()
	return found


# --- Feed, camera roll and lab -----------------------------------------------------------

## The feed, newest first.
static func feed(profile: PlayerProfile) -> Array:
	var found := arrived(profile, "feed")
	found.reverse()
	return found.slice(0, FEED_SHOWN)


## The camera roll, newest first: the doctor's own photos and every photo
## sent in a chat (saved automatically, as phones do).
static func photos(profile: PlayerProfile) -> Array:
	var found: Array = []
	for item: Dictionary in arrived(profile):
		if item["kind"] == "photo" or (item["kind"] == "chat" and not str(item["photo"]).is_empty() and not item["deleted"]):
			found.append(item)
	found.reverse()
	return found.slice(0, PHOTOS_SHOWN)


## Lab reports, newest first: the story's and casualty's own (live: the
## ward's results today, as items with kind "lab").
static func lab(profile: PlayerProfile, live: Array = []) -> Array:
	var found := arrived(profile, "lab").filter(func(item: Dictionary) -> bool: return int(item["day"]) >= profile.day - 1)
	found.append_array(live)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["stamp"]) > int(b["stamp"]))
	return found


## Today's casualty results as lab items.
static func casualty_lab(profile: PlayerProfile, sim: ShiftSim) -> Array:
	var found: Array = []
	if sim == null:
		return found
	for patient: ShiftPatient in sim.patients:
		for test: String in patient.results:
			var at := int(patient.ordered.get(test, profile.minutes))
			var item := {"id": "cas_%d_%s" % [patient.id, test], "kind": "lab", "chat": "", "from": "lab",
				"text": "", "photo": "", "caption": "", "deleted": false, "reply": [],
				"patient": "%s, %d" % [patient.called(), patient.age],
				"test": str(Conditions.TESTS.get(test, {}).get("name", test)),
				"result": str(patient.results[test]),
				"high": (patient.condition.get("results", {}) as Dictionary).has(test)}
			_set_stamp(item, stamp(profile.day, at))
			found.append(item)
	return found


# --- The end of a day -------------------------------------------------------------------

## Remembers what a ward day was like (the evening's messages read it), and
## maybe a thank-you from someone casualty sent home well.
static func note_day(profile: PlayerProfile, day: int, sim: ShiftSim = null) -> void:
	var phone := state(profile)
	var tally := sim.summary() if sim != null else {}
	var started := int(profile.morning.get("total_xp", profile.total_xp)) if int(profile.morning.get("day", -1)) == day \
		else profile.total_xp
	phone["days"][str(day)] = {
		"lost": (profile.count("op_streak_ended_day") == day and profile.count("op_lost") == 1)
			or int(tally.get("died", 0)) > 0,
		"xp": profile.total_xp - started,
		"seen": int(tally.get("seen", 0)),
		"right": int(tally.get("right", 0)),
		"lead": Rival.lead(profile, day) if Rival.racing(profile) else 0,
	}
	_trim_days(phone["days"])
	var thanks := PhoneWriter.thanks(profile, day, sim)
	var kept: Array = phone["kept"]
	kept.assign(kept.filter(func(entry: Dictionary) -> bool: return int(entry.get("day", 0)) != day))
	for written: Dictionary in [thanks, PhoneWriter.mortality(profile, day, sim)]:
		if not written.is_empty():
			kept.append(written)
	while kept.size() > KEPT_MAX:
		kept.pop_front()
	forget()


## The end-of-day card's line about the phone ("" when nobody writes
## tonight): the messages that arrive as this day closes.
static func evening_line(profile: PlayerProfile, day: int) -> String:
	var names: Array[String] = []
	var count := 0
	for item: Dictionary in items(profile):
		if item["kind"] != "chat" or item["from"] == "you" or int(item["day"]) != day or has_arrived(profile, item):
			continue
		count += 1
		var name := short_name(str(item["from"]), item)
		if name not in names:
			names.append(name)
	if names.is_empty():
		return ""
	if names.size() == 1:
		return "Phone: %s texted." % names[0] if count == 1 else "Phone: %d messages from %s." % [count, names[0]]
	if names.size() == 2:
		return "Phone: %s and %s texted." % [names[0], names[1]]
	return "Phone: %s, %s and %d more texted." % [names[0], names[1], names.size() - 2]
