class_name Rank
extends RefCounted
## The career ladder. Each rank covers a band of levels; later stages add
## the other things a promotion needs (operations, sign-offs, standing).

enum { INTERN, JUNIOR_RESIDENT, SENIOR_RESIDENT, SURGEON, HEAD_OF_DEPARTMENT, CHIEF }

const TITLES := ["Intern", "Junior Resident", "Senior Resident", "Surgeon", "Head of Department", "Chief of Medicine"]
## The first level of each rank.
const FIRST_LEVELS := [1, 4, 7, 10, 14, 18]


## The rank held at a level.
static func for_level(level: int) -> int:
	var rank := INTERN
	for index in FIRST_LEVELS.size():
		if level >= FIRST_LEVELS[index]:
			rank = index
	return rank


static func title(rank: int) -> String:
	return TITLES[clampi(rank, 0, TITLES.size() - 1)]


## The next rank, or -1 at the top.
static func next(rank: int) -> int:
	return rank + 1 if rank < CHIEF else -1


static func count() -> int:
	return TITLES.size()
