class_name DailyReward
extends RefCounted
## A little XP for opening the game on a new real-world day, more for each
## day in a row (up to a week), and more for each rank. The career's very
## first session only notes the date: there is nothing to come back for yet.
##
## The XP goes into the morning snapshot too, so a day that starts over
## after the game was closed halfway keeps it (see PlayerProfile.begin_day).

## XP on the first day back, and for each day in a row on top, up to MAX_STEPS.
const BASE_XP := 10
const STEP_XP := 5
const MAX_STEPS := 6
## The days-in-a-row count on the profile.
const COUNTER := "day_streak"
## Each rank adds this much again, as for drills.
const RANK_STEP := 0.5

## Tests set a date here; the game uses the device's local date.
static var today_override := ""


## The local date, as "2026-11-16".
static func today() -> String:
	return today_override if not today_override.is_empty() else Time.get_date_string_from_system(false)


## The day before a date in the same form.
static func yesterday(date: String) -> String:
	var noon := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(noon - 24 * 60 * 60)


## The XP for a day in a row at a rank.
static func xp_for(streak: int, rank: int) -> int:
	var plain := BASE_XP + STEP_XP * clampi(streak - 1, 0, MAX_STEPS)
	return int(roundf(plain * (1.0 + RANK_STEP * maxi(0, rank))))


## Notes a session on a date. The first session of a new date pays the XP
## and returns {"xp", "streak", "next"} (next: tomorrow's XP); any later
## session that day, the career's first ever, and any while the phone's
## date is earlier than one already seen (ClockGuard), return {}.
static func claim(profile: PlayerProfile, date: String = "") -> Dictionary:
	var when := date if not date.is_empty() else today()
	if ClockGuard.rolled_back(profile, when):
		# The phone's date was moved back: nothing until it catches up.
		return {}
	ClockGuard.note(profile, when)
	if profile.last_played == when:
		return {}
	var first := profile.last_played.is_empty()
	var streak := 1
	if profile.last_played == yesterday(when):
		streak = maxi(1, profile.count(COUNTER, 0)) + 1
	profile.last_played = when
	profile.set_count(COUNTER, streak)
	if first:
		return {}
	var rank := profile.rank()
	var xp := xp_for(streak, rank)
	profile.total_xp += xp
	if int(profile.morning.get("day", -1)) == profile.day:
		profile.morning["total_xp"] = int(profile.morning.get("total_xp", profile.total_xp - xp)) + xp
	return {"xp": xp, "streak": streak, "next": xp_for(streak + 1, rank)}
