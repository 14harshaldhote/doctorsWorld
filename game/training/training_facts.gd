class_name TrainingFacts
extends RefCounted
## True stories and facts from medicine for the training stations, shown on
## the score card ("Did you know?") on Day 2 and read out on the drill card
## between days. Each station has its own list; the nth visit shows the nth
## fact, so a doctor who keeps practising keeps learning something new.
##
## The stories live in story/facts.json ("facts", by station) so the voice
## tool (tools/make_voices.py) records each one in its trainer's voice.


## Every station's stories, by station id.
static func all() -> Dictionary:
	var found: Variant = StoryBook.chapter("facts").get("facts", {})
	return found if typeof(found) == TYPE_DICTIONARY else {}


## The nth fact for a station (wrapping round), or "" for a station with none.
static func fact(station: String, index: int) -> String:
	var list: Array = all().get(station, [])
	if list.is_empty():
		return ""
	return str(list[posmod(index, list.size())])


static func count(station: String) -> int:
	return (all().get(station, []) as Array).size()
