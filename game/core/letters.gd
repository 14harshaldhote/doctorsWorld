class_name Letters
extends RefCounted
## Post from the people the doctor looked after (story/letters.json). Each
## slot is one place on the wall; the first of its letters whose condition
## holds arrives as the day "after" ends, so what the player did decides
## which letter comes, or whether one comes at all. Opening a letter marks
## it read (flag "letter_read_<slot>").

const PATH := "res://story/letters.json"
const READ_FLAG := "letter_read_"

static var _slots: Array = []


## Every slot on the wall, in the order they arrive.
static func slots() -> Array:
	if _slots.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_slots = (parsed as Dictionary).get("slots", [])
	return _slots


## The letter a slot holds for this career, or {} when nobody wrote.
static func letter_for(profile: PlayerProfile, slot: Dictionary) -> Dictionary:
	for letter: Dictionary in slot.get("letters", []):
		if WardStory.holds(profile, str(letter.get("when", ""))):
			return letter
	return {}


## Where a slot stands: "arrived" (a letter came), "none" (its day passed and
## nobody wrote) or "sealed" (its day hasn't come).
static func state(profile: PlayerProfile, slot: Dictionary) -> String:
	if profile.day <= int(slot.get("after", 0)):
		return "sealed"
	return "arrived" if not letter_for(profile, slot).is_empty() else "none"


## The slots whose letter has arrived, oldest first.
static func arrived(profile: PlayerProfile) -> Array:
	return slots().filter(func(slot: Dictionary) -> bool: return state(profile, slot) == "arrived")


static func is_read(profile: PlayerProfile, slot: Dictionary) -> bool:
	return profile.has_flag(READ_FLAG + str(slot.get("id", "")))


static func unread_count(profile: PlayerProfile) -> int:
	return arrived(profile).filter(func(slot: Dictionary) -> bool: return not is_read(profile, slot)).size()


static func mark_read(profile: PlayerProfile, slot: Dictionary) -> void:
	var flag := READ_FLAG + str(slot.get("id", ""))
	profile.set_flag(flag)
	# Reading isn't part of the day: a day played again from the start
	# doesn't seal the letter again.
	if profile.morning.get("flags") is Dictionary:
		(profile.morning["flags"] as Dictionary)[flag] = true


## The letters that arrive as this day ends.
static func arriving(profile: PlayerProfile, day: int) -> Array:
	var found: Array = []
	for slot: Dictionary in slots():
		if int(slot.get("after", 0)) == day and not letter_for(profile, slot).is_empty():
			found.append(slot)
	return found


## The end-of-day card's line about post, or "".
static func post_line(profile: PlayerProfile, day: int) -> String:
	var coming := arriving(profile, day)
	if coming.is_empty():
		return ""
	var first := str(letter_for(profile, coming[0]).get("from", "someone"))
	if coming.size() == 1:
		return "Post: a letter from %s. It's on your career map." % first
	return "Post: %d letters, one from %s. They're on your career map." % [coming.size(), first]


## A letter's text with the player's name in it.
static func body(profile: PlayerProfile, letter: Dictionary) -> String:
	return str(letter.get("body", "")).replace("{called}", profile.called())
