class_name PlayerProfile
extends RefCounted
## The player's career: their name, how people address them, their look,
## and the experience they have earned.

const MAX_NAME_LENGTH := 24
const DEFAULT_NAME := "Asha Verma"

var name := DEFAULT_NAME:
	set(value):
		name = clean_name(value)
## "first" for Dr. Asha, "last" for Dr. Verma.
var address_form := "last"
var avatar := AvatarConfig.new()
var total_xp := 0
var day := 1
## True once the player has finished the creator, so Continue makes sense.
var created := false


## Trims spaces, collapses runs of spaces and cuts overly long names.
## Letters from every language are kept.
static func clean_name(raw: String) -> String:
	var parts := raw.strip_edges().split(" ", false)
	var joined := " ".join(parts)
	return joined.substr(0, MAX_NAME_LENGTH).strip_edges()


func first_name() -> String:
	var parts := name.split(" ", false)
	return parts[0] if parts.size() > 0 else "Doctor"


func last_name() -> String:
	var parts := name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else "Doctor"


## "Dr. Asha Verma", or "Dr. Doctor" never: an empty name reads "Doctor".
func full_title() -> String:
	return "Dr. " + name if not name.is_empty() else "Doctor"


## What patients and staff call the player: "Dr. Verma" or "Dr. Asha".
func called() -> String:
	if name.is_empty():
		return "Doctor"
	return "Dr. " + (first_name() if address_form == "first" else last_name())


func level() -> int:
	return LevelCurve.level_for_xp(total_xp)


func rank() -> int:
	return Rank.for_level(level())


func to_dict() -> Dictionary:
	return {
		"name": name,
		"address_form": address_form,
		"avatar": avatar.to_dict(),
		"total_xp": total_xp,
		"day": day,
		"created": created,
	}


static func from_dict(data: Variant) -> PlayerProfile:
	var profile := PlayerProfile.new()
	if typeof(data) != TYPE_DICTIONARY:
		return profile
	if typeof(data.get("name")) == TYPE_STRING:
		profile.name = data["name"]
	if data.get("address_form") in ["first", "last"]:
		profile.address_form = data["address_form"]
	profile.avatar = AvatarConfig.from_dict(data.get("avatar"))
	var xp: Variant = data.get("total_xp")
	if typeof(xp) in [TYPE_INT, TYPE_FLOAT] and float(xp) >= 0.0:
		profile.total_xp = int(xp)
	var saved_day: Variant = data.get("day")
	if typeof(saved_day) in [TYPE_INT, TYPE_FLOAT] and float(saved_day) >= 1.0:
		profile.day = int(saved_day)
	if typeof(data.get("created")) == TYPE_BOOL:
		profile.created = data["created"]
	return profile
