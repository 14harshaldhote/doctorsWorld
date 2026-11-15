class_name Standing
extends RefCounted
## How the hospital is doing once the doctor runs it: three numbers from 0
## to 100 that the Chief's hard calls push up and down.
##   staff   whether the people who work here would stay if asked elsewhere
##   money   whether the hospital can pay for what it promised
##   public  whether the town trusts the place with its relatives
## They are kept in the profile's counters, and each also raises a flag when
## it is low or high ("staff_low", "money_high"), so the story can notice.

const METERS := ["staff", "money", "public"]
const NAMES := {"staff": "Staff", "money": "Money", "public": "Public trust"}
const SHORT := {"staff": "Staff", "money": "Money", "public": "Trust"}
const START := 55
## At or below LOW a meter is in trouble; at or above HIGH it is a strength.
const LOW := 35
const HIGH := 72
## What the story's own choices did to the hospital before the first Chief's
## day: [condition, {meter: change}].
const HISTORY := [
	["strike_backed|strike_talks", {"staff": 8}],
	["strike_opposed", {"staff": -8}],
	["strike_agency", {"staff": -8, "money": -6}],
	["strike_no_agency", {"staff": 5}],
	["strike_rota_right", {"public": 5}],
	["strike_rota_gap", {"public": -6}],
	["sinha_together|sinha_told", {"public": 8}],
	["sinha_covered", {"public": -10}],
	["vote_night_doctor", {"staff": 6, "money": -5}],
	["vote_robot", {"money": 5, "staff": -4}],
	["candour_together|candour_rao", {"public": 5}],
	["candour_hidden|candour_lied", {"public": -6}],
	["beds_saved", {"public": 4}],
	["board_owned", {"money": 4}],
	["crash_credit_priya", {"staff": 4}],
	["mm_took_credit|mm_blame_zoya", {"staff": -5}],
]


static func value(profile: PlayerProfile, meter: String) -> int:
	return profile.count("standing_" + meter, START)


## True once the Chief's first morning has set the numbers up.
static func started(profile: PlayerProfile) -> bool:
	return profile.count("standing_set") > 0


## Sets the three numbers from what the doctor did on the way up. Does
## nothing the second time.
static func start(profile: PlayerProfile) -> void:
	if started(profile):
		return
	for meter: String in METERS:
		profile.set_count("standing_" + meter, START)
	for entry: Array in HISTORY:
		if WardStory.holds(profile, str(entry[0])):
			change(profile, entry[1])
	profile.set_count("standing_set", 1)
	sync_flags(profile)


## Moves the meters: {"staff": 5, "money": -4}. Returns what moved,
## {meter: [change, new value]}.
static func change(profile: PlayerProfile, changes: Dictionary) -> Dictionary:
	var moved := {}
	for meter: Variant in changes:
		if str(meter) not in METERS:
			continue
		var before := value(profile, str(meter))
		var after := clampi(before + int(changes[meter]), 0, 100)
		profile.set_count("standing_" + str(meter), after)
		moved[str(meter)] = [after - before, after]
	sync_flags(profile)
	return moved


static func is_low(profile: PlayerProfile, meter: String) -> bool:
	return value(profile, meter) <= LOW


static func is_high(profile: PlayerProfile, meter: String) -> bool:
	return value(profile, meter) >= HIGH


## Keeps the flags the story reads in step with the numbers.
static func sync_flags(profile: PlayerProfile) -> void:
	for meter: String in METERS:
		profile.set_flag(meter + "_low", is_low(profile, meter))
		profile.set_flag(meter + "_high", is_high(profile, meter))


## "Staff +6 · Money -4", for the line under a reply.
static func describe(moved: Dictionary) -> String:
	var parts := PackedStringArray()
	for meter: String in METERS:
		if moved.has(meter) and int(moved[meter][0]) != 0:
			parts.append("%s %+d" % [SHORT[meter], int(moved[meter][0])])
	return " · ".join(parts)


## "Staff 62 · Money 48 · Trust 71".
static func summary(profile: PlayerProfile) -> String:
	var parts := PackedStringArray()
	for meter: String in METERS:
		parts.append("%s %d" % [SHORT[meter], value(profile, meter)])
	return " · ".join(parts)


static func total(profile: PlayerProfile) -> int:
	var sum := 0
	for meter: String in METERS:
		sum += value(profile, meter)
	return sum


## The meter in the most trouble.
static func weakest(profile: PlayerProfile) -> String:
	var found := str(METERS[0])
	for meter: String in METERS:
		if value(profile, meter) < value(profile, found):
			found = meter
	return found


## The board's word on the three numbers: "strong" (none low, at least one
## high, a good total), "poor" (two low, or a low total), or "mixed". bar
## raises both totals: the board expects more as the years go by.
static func verdict(profile: PlayerProfile, bar: int = 0) -> String:
	var low := 0
	var high := 0
	for meter: String in METERS:
		low += int(is_low(profile, meter))
		high += int(is_high(profile, meter))
	if low == 0 and high >= 1 and total(profile) >= 180 + bar:
		return "strong"
	if low >= 2 or total(profile) < 130 + bar:
		return "poor"
	return "mixed"
