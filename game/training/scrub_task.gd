class_name ScrubTask
extends TrainingTask
## Scrub in: wash in the right order, scrub every part of both hands for
## long enough, then towel, gown and gloves without touching anything.
##
## The steps run water, soap, scrub (six areas, held), rinse, towel, gown,
## gloves. A step out of order is a mistake that does not happen. Touching
## your face after the soap means starting again from the soap.

## Seconds of scrubbing each area needs.
const SCRUB_TIME := 1.5
## The steps that move you on, in order, with what the button says.
const STEPS := ["water", "soap", "scrub", "rinse", "towel", "gown", "gloves"]
const AREAS := ["palms", "backs", "fingers", "thumbs", "nails", "wrists"]
const TRAPS := ["mask", "nose"]
const LABELS := {
	"water": "Water on",
	"soap": "Soap",
	"rinse": "Rinse",
	"towel": "Sterile towel",
	"gown": "Gown",
	"gloves": "Gloves",
	"palms": "Palms",
	"backs": "Backs of hands",
	"fingers": "Between fingers",
	"thumbs": "Thumbs",
	"nails": "Nails",
	"wrists": "Wrists",
	"mask": "Fix your mask",
	"nose": "Scratch your nose",
}
## Why a step cannot come yet, keyed by the step that was tried too early.
const TOO_EARLY := {
	"soap": "Water first. Soap on dry hands doesn't lather.",
	"scrub": "Soap first, then scrub.",
	"rinse": "Rinse what? Soap and scrub first.",
	"towel": "Wash and rinse first, then dry.",
	"gown": "Dry hands first, or the gown soaks through and stops being sterile.",
	"gloves": "Gown first, then gloves over the cuffs.",
}
const POINTS_PER_MISTAKE := 8
const POINTS_PER_SKIPPED_AREA := 12
const POINTS_PER_CONTAMINATION := 25

## The next step needed, as an index into STEPS (7 when gloved). Rinsing
## from the scrub stage moves straight on to the towel.
var stage := 0
var mistakes := 0
var contaminations := 0
## Seconds scrubbed per area.
var scrubbed := {}
var skipped: Array[String] = []
var _mistake_lines: Array[String] = []


func _init() -> void:
	id = "scrub"
	_reset_scrub()
	_say("Water on first. Then soap, then every part of both hands.")


static func label_of(step: String) -> String:
	return str(LABELS.get(step, step.capitalize()))


func is_area(step: String) -> bool:
	return step in AREAS


## True once the hands are soaped: from here on, touching anything counts.
func hands_clean() -> bool:
	return stage >= 2


func area_done(area: String) -> bool:
	return float(scrubbed.get(area, 0.0)) >= SCRUB_TIME


func areas_done() -> int:
	var done := 0
	for area: String in AREAS:
		if area_done(area):
			done += 1
	return done


## The step the task expects next (a scrub area while scrubbing).
func next_expected() -> String:
	if stage == 2:
		for area: String in AREAS:
			if not area_done(area):
				return area
		return "rinse"
	return STEPS[stage] if stage < STEPS.size() else ""


## A tap on a step's button. Scrub areas are held instead: see begin_scrub().
func do_step(step: String) -> void:
	if finished:
		return
	if step in TRAPS:
		_touch(step)
		return
	if is_area(step):
		begin_scrub(step)
		return
	var wanted := STEPS.find(step)
	if wanted < 0:
		return
	if wanted < stage:
		_say("Already done. Keep going.")
		return
	if wanted > stage:
		# Rinsing early from the scrub stage is allowed, with what was skipped noted.
		if not (step == "rinse" and stage == 2):
			_mistake(step)
			return
	if step == "rinse":
		_rinse()
		return
	stage = wanted + 1
	match step:
		"water":
			_say("Good. Now soap.")
		"soap":
			stage = 2
			_say("Now scrub. Hold each part until it's done. From here on, touch nothing.")
		"towel":
			_say("Dry. Now the gown.")
		"gown":
			_say("Gown on. Gloves last, over the cuffs.")
		"gloves":
			_say("Gloved. You're sterile. Don't wave at anyone.")
			_finish_scrub()


## The start of holding a scrub area's button.
func begin_scrub(area: String) -> void:
	if finished or not is_area(area):
		return
	if stage < 2:
		_mistake("scrub")
	elif stage > 2:
		_say("You've already rinsed. Scrubbing again means starting over: leave it.")


## Holding a scrub area's button for delta seconds.
func scrub(area: String, delta: float) -> void:
	if finished or stage != 2 or not is_area(area):
		return
	var was_done := area_done(area)
	scrubbed[area] = minf(SCRUB_TIME, float(scrubbed.get(area, 0.0)) + delta)
	if area_done(area) and not was_done:
		var left := AREAS.size() - areas_done()
		if left == 0:
			_say("All six. Rinse, fingertips up, so the water runs off at the elbows.")
		else:
			_say("%s done. %d to go." % [label_of(area), left])


func score() -> int:
	var points := 100 - mistakes * POINTS_PER_MISTAKE - skipped.size() * POINTS_PER_SKIPPED_AREA \
		- contaminations * POINTS_PER_CONTAMINATION
	return clampi(points, 0, 100)


func instruction() -> String:
	match stage:
		0:
			return "Turn the water on and wet your hands"
		1:
			return "Soap up"
		2:
			return "Hold each part to scrub it: %d of %d done" % [areas_done(), AREAS.size()]
		4:
			return "Dry your hands with a sterile towel"
		5:
			return "Put on the gown"
		6:
			return "Gloves on, over the cuffs"
	return "Scrubbed in"


func progress() -> float:
	var done := float(mini(stage, 2))
	if stage == 2:
		done += float(areas_done()) / AREAS.size()
	elif stage > 2:
		done = float(stage)
	return clampf(done / STEPS.size(), 0.0, 1.0)


func _touch(step: String) -> void:
	if not hands_clean():
		_say("Fine, your hands aren't clean yet. After the soap, though: hands off.")
		return
	contaminations += 1
	stage = 1
	_reset_scrub()
	var what := "your mask" if step == "mask" else "your nose"
	_say("You touched %s. Those hands aren't clean any more. Back to the soap." % what, true)


func _mistake(step: String) -> void:
	mistakes += 1
	var line := str(TOO_EARLY.get(step, "Not yet."))
	if line not in _mistake_lines:
		_mistake_lines.append(line)
	_say(line, true)


func _rinse() -> void:
	skipped.clear()
	for area: String in AREAS:
		if not area_done(area):
			skipped.append(area)
	stage = STEPS.find("towel")
	if skipped.is_empty():
		_say("Rinsed, fingertips up. Now the towel.")
	else:
		var names := PackedStringArray()
		for area: String in skipped:
			names.append(label_of(area).to_lower())
		_say("You skipped: %s. Germs love the bits you skip." % ", ".join(names), true)


func _reset_scrub() -> void:
	for area: String in AREAS:
		scrubbed[area] = 0.0


func _finish_scrub() -> void:
	if skipped.is_empty():
		_note(true, "Every part of both hands scrubbed for long enough.")
	else:
		var names := PackedStringArray()
		for area: String in skipped:
			names.append(label_of(area).to_lower())
		_note(false, "You skipped %s. Germs hide there, and they end up in the wound." % " and ".join(names))
	if contaminations == 0:
		_note(true, "Hands stayed clear of your face and mask after washing.")
	else:
		_note(false, "You touched your face after washing %s. In theatre, that means scrubbing again from the start." %
			("once" if contaminations == 1 else "%d times" % contaminations))
	if mistakes == 0:
		_note(true, "Every step in the right order.")
	else:
		for line in _mistake_lines.slice(0, 2):
			_note(false, line)
	_finish()
