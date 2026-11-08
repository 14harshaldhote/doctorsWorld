class_name LevelCurve
extends RefCounted
## How much experience each level needs.
##
## Reaching level n takes a total of BASE × n^1.5 XP, rounded to the nearest
## 10. Level 2 needs 710 XP, level 4 (Junior Resident) 2,000 XP and level 10
## 7,910 XP. Ported unchanged from the Swift prototype.

const BASE := 250.0
const MAX_LEVEL := 50


## Total XP needed to reach a level. Level 1 needs nothing.
static func total_xp_to_reach(level: int) -> int:
	if level <= 1:
		return 0
	var raw := BASE * pow(float(mini(level, MAX_LEVEL)), 1.5)
	return int(roundf(raw / 10.0)) * 10


## The level a player with this much total XP has reached.
static func level_for_xp(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= total_xp_to_reach(level + 1):
		level += 1
	return level


## Position inside the current level, for drawing an XP bar:
## {level, into, needed, fraction}. needed is 0 at the maximum level.
static func progress(xp: int) -> Dictionary:
	var level := level_for_xp(xp)
	var start := total_xp_to_reach(level)
	if level >= MAX_LEVEL:
		return {"level": level, "into": xp - start, "needed": 0, "fraction": 1.0}
	var needed := total_xp_to_reach(level + 1) - start
	return {"level": level, "into": xp - start, "needed": needed, "fraction": float(xp - start) / float(needed)}
