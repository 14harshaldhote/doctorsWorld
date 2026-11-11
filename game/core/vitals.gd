class_name Vitals
extends RefCounted
## A patient's vital signs as a monitor shows them, with the normal ranges
## the game uses. Simplified for a game, not for real patients.

const KINDS := ["hr", "bp", "spo2", "rr"]
const NAMES := {"hr": "Heart rate", "bp": "Blood pressure", "spo2": "Oxygen", "rr": "Breathing rate"}
const LABELS := {"hr": "HEART", "bp": "BP", "spo2": "OXYGEN", "rr": "BREATHS"}
const NORMAL := {
	"hr": "60 to 100 beats a minute",
	"bp": "about 120 over 80; the top number between 90 and 140",
	"spo2": "95% or more",
	"rr": "12 to 20 breaths a minute",
}
const MEANING := {
	"hr": "how fast the heart beats",
	"bp": "how hard the blood pushes on the vessel walls",
	"spo2": "how much oxygen the blood is carrying",
	"rr": "how many breaths a minute",
}

var hr := 78
var systolic := 118
var diastolic := 76
var spo2 := 98
var rr := 14


func is_normal(kind: String) -> bool:
	match kind:
		"hr":
			return hr >= 60 and hr <= 100
		"bp":
			return systolic >= 90 and systolic <= 140 and diastolic >= 55 and diastolic <= 90
		"spo2":
			return spo2 >= 95
		"rr":
			return rr >= 12 and rr <= 20
	return true


## The kinds that are out of range, in KINDS order.
func problems() -> Array[String]:
	var found: Array[String] = []
	for kind: String in KINDS:
		if not is_normal(kind):
			found.append(kind)
	return found


func value_text(kind: String) -> String:
	match kind:
		"hr":
			return str(hr)
		"bp":
			return "%d/%d" % [systolic, diastolic]
		"spo2":
			return "%d%%" % spo2
		"rr":
			return str(rr)
	return ""


## 1 when a number is too high, -1 when too low, 0 when normal.
func direction(kind: String) -> int:
	var words := problem_words(kind)
	if words.is_empty():
		return 0
	return 1 if words in ["too fast", "too high"] else -1


## "too fast", "too low" and so on, or "" when normal.
func problem_words(kind: String) -> String:
	if is_normal(kind):
		return ""
	match kind:
		"hr":
			return "too fast" if hr > 100 else "too slow"
		"bp":
			return "too high" if systolic > 140 or diastolic > 90 else "too low"
		"spo2":
			return "too low"
		"rr":
			return "too fast" if rr > 20 else "too slow"
	return ""


## Healthy numbers that wobble a little, so no two screens look the same.
static func healthy(rng: SeededRandom) -> Vitals:
	var vitals := Vitals.new()
	vitals.hr = rng.next_int_in(64, 92)
	vitals.systolic = rng.next_int_in(108, 132)
	vitals.diastolic = rng.next_int_in(66, 84)
	vitals.spo2 = rng.next_int_in(96, 99)
	vitals.rr = rng.next_int_in(12, 18)
	return vitals


## Healthy numbers with one problem: kind "hr", "bp", "spo2" or "rr" and
## direction "high" or "low".
static func with_problem(rng: SeededRandom, kind: String, direction: String) -> Vitals:
	var vitals := healthy(rng)
	match kind:
		"hr":
			vitals.hr = rng.next_int_in(118, 136) if direction == "high" else rng.next_int_in(40, 50)
		"bp":
			if direction == "high":
				vitals.systolic = rng.next_int_in(166, 184)
				vitals.diastolic = rng.next_int_in(98, 110)
			else:
				vitals.systolic = rng.next_int_in(74, 84)
				vitals.diastolic = rng.next_int_in(40, 50)
		"spo2":
			vitals.spo2 = rng.next_int_in(85, 91)
		"rr":
			vitals.rr = rng.next_int_in(26, 34) if direction == "high" else rng.next_int_in(6, 9)
	return vitals
