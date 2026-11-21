class_name ClockGuard
extends RefCounted
## Keeps the daily rewards honest when the phone's date is moved back. The
## career remembers the latest date it has seen; while the phone says an
## earlier one, nothing daily pays (the daily XP, the 60-second case) until
## the real date catches up. Moving the date forward can't be told apart
## from a long weekend, but it only brings the next days early: going back
## afterwards finds them locked, so there's nothing to gain.

## The career's latest date, as 20261121, in the counters.
const COUNTER := "latest_date"


static func date_number(date: String) -> int:
	return int(date.replace("-", "")) if not date.is_empty() else 0


## The latest date the career has seen: noted, or the last daily XP or case.
static func latest(profile: PlayerProfile) -> int:
	return maxi(maxi(profile.count(COUNTER), date_number(profile.last_played)), profile.count("daily_case_date"))


## True while the phone's date is earlier than one the career has seen.
static func rolled_back(profile: PlayerProfile, date: String = "") -> bool:
	var when := date if not date.is_empty() else DailyReward.today()
	return date_number(when) < latest(profile)


## Remembers a date if it's the latest yet.
static func note(profile: PlayerProfile, date: String = "") -> void:
	var when := date if not date.is_empty() else DailyReward.today()
	if date_number(when) > profile.count(COUNTER):
		profile.set_count(COUNTER, date_number(when))
