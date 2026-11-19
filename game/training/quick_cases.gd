class_name QuickCases
extends RefCounted
## The daily 60-second cases: twelve quick emergencies, each three questions
## whose answers come from facts rolled from the day's seed (the sugar
## reading, the child's weight, which leads have ST elevation, how many
## hours since the stroke began, where the burns are). Played with
## CrisisTask like the crises, against one clock for the whole case. Dr.
## Iyer coaches, with the lines under "quick" in story/crisis_lines.json.
##
## The rules are simplified from standard emergency teaching (Indian and
## WHO guidance) so the game teaches nothing wrong.

const IDS := ["quick_sugar", "quick_allergy", "quick_stroke", "quick_heart", "quick_diarrhoea", "quick_burns", "quick_asthma",
	"quick_seizure", "quick_head", "quick_poison", "quick_sepsis", "quick_heat"]
const ACTOR := "iyer"


## True while building a case for a story day on the ward, where the talk
## around it names the patient (the constable, the painter, the grandmother).
static var _story := false


static func build(case_id: String, dice: SeededRandom, level: String, context: Dictionary = {}) -> Dictionary:
	_story = bool(context.get("story", false))
	var made: Dictionary
	match case_id:
		"quick_sugar":
			made = _sugar(dice, level)
		"quick_allergy":
			made = _allergy(dice, level)
		"quick_stroke":
			made = _stroke(dice, level)
		"quick_heart":
			made = _heart(dice, level)
		"quick_diarrhoea":
			made = _diarrhoea(dice, level)
		"quick_burns":
			made = _burns(dice, level)
		"quick_asthma":
			made = _asthma(dice, level)
		"quick_seizure":
			made = _seizure(dice, level)
		"quick_head":
			made = _head(dice, level)
		"quick_poison":
			made = _poison(dice, level)
		"quick_sepsis":
			made = _sepsis(dice, level)
		"quick_heat":
			made = _heat(dice, level)
		_:
			push_error("Unknown quick case: %s" % case_id)
			return {}
	made["actor"] = ACTOR
	made["spot"] = "Casualty"
	return made


static func _opt(id: String, text: String) -> Dictionary:
	return {"id": id, "text": text}


static func _step(dice: SeededRandom, id: String, prompt: String, options: Array, answer: String, why: String,
		good: String = "") -> Dictionary:
	return {"id": id, "kind": "one", "prompt": prompt, "options": dice.shuffled(options), "answer": answer,
		"right": "right", "wrong": "wrong", "hint": "hint", "why": why, "good": good if not good.is_empty() else why}


## Three or four numbers near the right one, all different, as options.
static func _numbers(dice: SeededRandom, right: int, unit: String, near: Array) -> Array:
	var seen := {right: true}
	var options: Array = [_opt("n%d" % right, "%s %s" % [_grouped(right), unit])]
	for value: Variant in near:
		var number := int(value)
		if number <= 0 or seen.has(number):
			continue
		seen[number] = true
		options.append(_opt("n%d" % number, "%s %s" % [_grouped(number), unit]))
		if options.size() >= 4:
			break
	return dice.shuffled(options)


static func _grouped(number: int) -> String:
	var text := str(number)
	return text if text.length() <= 3 else text.substr(0, text.length() - 3) + "," + text.substr(text.length() - 3)


# --- Sugar: low, very high, or not the sugar at all ------------------------------------------

static func _sugar(dice: SeededRandom, level: String) -> Dictionary:
	var kinds := ["low", "low", "high", "normal"] if level != "easy" else ["low", "high"]
	var kind: String = dice.pick(kinds)
	var awake: bool = kind != "low" or level == "easy" or dice.chance(0.5)
	var who: String = dice.pick(["Mr. Shantaram Bhosle, 64, diabetic on insulin", "Mrs. Nasreen Qureshi, 57, diabetic on tablets and insulin",
		"Mr. Joseph Mathai, 49, 'sugar patient' for twelve years"])
	var reading: int = {"low": dice.next_int_in(38, 62), "high": dice.next_int_in(420, 560), "normal": dice.next_int_in(104, 138)}[kind]
	var facts: Array[String] = [who, "Brought in confused by his son: 'He was talking nonsense since lunch.'" if who.begins_with("Mr.")
		else "Brought in confused by her daughter: 'She was talking nonsense since lunch.'",
		"Bedside sugar (CBG): %d mg/dL" % reading,
		"Urine ketones: ++++, breathing deep and fast" if kind == "high" else "Urine ketones: none",
		("Drowsy, can't swallow safely" if not awake else "Awake, sweaty, can swallow") if kind == "low"
			else ("Right arm weak, speech slurred since 1 p.m." if kind == "normal" else "Dry tongue, very thirsty")]
	var steps: Array = []
	steps.append(_step(dice, "s1", "The sugar reads %d. What's going on?" % reading, [
		_opt("low", "Low sugar (hypoglycaemia)"), _opt("high", "Diabetic ketoacidosis (DKA)"),
		_opt("normal", "Not the sugar: think stroke"), _opt("drunk", "A drink at lunch, obviously")], kind,
		"Under 70 mg/dL is low. Very high with ketones and fast deep breathing is DKA. A normal sugar with a weak arm and slurred speech is a stroke until proved otherwise."))
	var treat: Array = {
		"low": [_opt("oral", "15 to 20 g of glucose by mouth (four glucose tablets, or 150 ml of juice)"),
			_opt("iv", "IV dextrose now (25% dextrose), no food or drink by mouth"),
			_opt("insulin", "The usual insulin dose, it was missed"), _opt("sweets", "A box of pedas from the canteen")],
		"high": [_opt("fluids", "IV fluids first, then an insulin drip"), _opt("oral", "Glucose by mouth"),
			_opt("bolus", "A big dose of insulin into the vein, now"), _opt("home", "Double the tablets and send them home")],
		"normal": [_opt("ct", "Urgent CT head: the stroke clock is running"), _opt("oral", "Glucose by mouth, just in case"),
			_opt("insulin", "Insulin, to be safe"), _opt("wait", "Watch till evening")]}[kind]
	var treat_answer: String = {"low": "oral" if awake else "iv", "high": "fluids", "normal": "ct"}[kind]
	steps.append(_step(dice, "s2", "What do you do first?", treat, treat_answer,
		{"low": "Awake and able to swallow: sugar by mouth. Drowsy or can't swallow: IV dextrose, never by mouth (it goes into the lungs)." ,
			"high": "DKA kills with dehydration first: IV fluids, then insulin as a drip. A big insulin bolus drops the potassium dangerously.",
			"normal": "The sugar is fine, so the confusion is something else. A weak arm and slurred speech: CT head now."}[kind]))
	var next: Array = {
		"low": [_opt("recheck", "Check the sugar again in 15 minutes, then a proper meal"), _opt("insulin", "Restart the insulin straight away"),
			_opt("home", "Send them home once they're talking"), _opt("hba1c", "Order an HbA1c")],
		"high": [_opt("potassium", "Check the potassium before and during the insulin"), _opt("sugar", "Stop once the sugar is 250"),
			_opt("home", "Send them home once the sugar is normal"), _opt("xray", "A chest X-ray before anything")],
		"normal": [_opt("time", "Find out exactly when they were last seen normal"), _opt("sugar", "Recheck the sugar every 15 minutes"),
			_opt("hba1c", "Order an HbA1c"), _opt("home", "Send them home with aspirin")]}[kind]
	var next_answer: String = {"low": "recheck", "high": "potassium", "normal": "time"}[kind]
	steps.append(_step(dice, "s3", "And next?", next, next_answer,
		{"low": "Low sugar comes back. Recheck in 15 minutes, then a meal with long-acting carbohydrate.",
			"high": "Insulin pushes potassium into the cells: check it before and during, and replace it.",
			"normal": "Clot-busting treatment depends on when the patient was last seen normal. Ask before anything else."}[kind]))
	return {"title": "The confused diabetic", "card": "CASUALTY · BED 1", "facts": facts, "steps": steps}


# --- An allergy, or a faint ------------------------------------------------------------------

static func _allergy(dice: SeededRandom, level: String) -> Dictionary:
	var faint: bool = level != "easy" and dice.chance(0.35)
	var child: bool = level != "easy" and dice.chance(0.5)
	var kg: int = dice.pick([15, 20, 25, 30]) if child else dice.next_int_in(52, 80)
	var who := ("Aryan, 6, %d kg, ceftriaxone injection for typhoid" % kg) if child \
		else "Mrs. Rekha Salunkhe, 34, %d kg, IV antibiotic for a kidney infection" % kg
	var signs: Array = ["Two minutes after the injection: pale, sweaty, slow pulse (52), BP 104/70",
		"No rash, no wheeze, no swelling. 'I always faint at needles,' says the family."] if faint \
		else ["Two minutes after the injection: hives everywhere, lips swelling, wheezing",
			"Pulse 128, BP 78/46"]
	var facts: Array[String] = [who]
	facts.append_array(signs)
	facts.append("Adrenaline on the trolley: 1 mg in 1 ml (1:1000)")
	var steps: Array = []
	steps.append(_step(dice, "s1", "What is this?", [_opt("anaphylaxis", "Anaphylaxis"), _opt("faint", "A simple faint (vasovagal)"),
		_opt("asthma", "An asthma attack"), _opt("panic", "Panic attack")], "faint" if faint else "anaphylaxis",
		"A fast pulse, low pressure, wheeze, hives and swelling after a drug is anaphylaxis. Pale with a slow pulse and nothing else is a faint." ))
	var dose_ml := minf(0.5, 0.01 * kg)
	var dose_text := "%.2f ml" % dose_ml if child else "0.5 ml"
	if faint:
		steps.append(_step(dice, "s2", "What do you do?", [_opt("legs", "Lie them flat and raise the legs"),
			_opt("adrenaline", "Adrenaline 0.5 ml IM"), _opt("sit", "Sit them up and give water"), _opt("steroid", "IV hydrocortisone")],
			"legs", "A faint gets better lying flat with the legs up. Adrenaline for a faint is how a faint becomes a heart problem."))
		steps.append(_step(dice, "s3", "Two minutes later: pink, pulse 80, chatting about cricket.", [
			_opt("watch", "Watch for half an hour, then carry on with the antibiotic"), _opt("adrenaline", "Adrenaline anyway, to be safe"),
			_opt("stop", "Stop the antibiotic for ever: write 'allergic'"), _opt("icu", "Shift to ICU")], "watch",
			"A faint is not an allergy. Writing 'allergic' on the file takes a useful antibiotic away for life."))
	else:
		var near: Array = ["%.2f ml" % (dose_ml * 2.0), "%.2f ml" % (dose_ml / 2.0), "5 ml"] if child else ["0.05 ml", "5 ml", "1 ml"]
		var options: Array = [_opt("right", "Adrenaline %s IM into the outer thigh" % dose_text)]
		var index := 0
		for wrong: String in near:
			index += 1
			if wrong != dose_text:
				options.append(_opt("wrong%d" % index, "Adrenaline %s IM into the outer thigh" % wrong))
		options.append(_opt("iv", "Adrenaline %s into the vein, fast" % dose_text))
		steps.append(_step(dice, "s2", "First drug, dose and route:", options.slice(0, 4), "right",
			"Adrenaline 1 mg/ml IM into the thigh: 0.01 ml per kg, no more than 0.5 ml. %s. Never 1:1000 into a vein." %
				("%d kg: %s" % [kg, dose_text] if child else "An adult gets 0.5 ml")))
		steps.append(_step(dice, "s3", "Five minutes later: still wheezing, BP 80/50.", [
			_opt("repeat", "Repeat the IM adrenaline, and run IV fluids"), _opt("steroid", "IV hydrocortisone and wait"),
			_opt("antihistamine", "An antihistamine injection and wait"), _opt("wait", "Give the first dose time")], "repeat",
			"Not better in five minutes: repeat the adrenaline and give fluids. Steroids and antihistamines are slow; they don't treat anaphylaxis."))
	return {"title": "Two minutes after the injection", "card": "CASUALTY · INJECTION ROOM", "facts": facts, "steps": steps}


# --- Stroke: the clock ------------------------------------------------------------------------

static func _stroke(dice: SeededRandom, level: String) -> Dictionary:
	var bleed: bool = level != "easy" and dice.chance(0.35)
	var hours: float = dice.pick([1.5, 2.5, 3.5, 4.0, 5.5, 7.0]) if level != "easy" else dice.pick([1.5, 2.5, 6.0])
	var woke: bool = level == "extreme" and dice.chance(0.4)
	var facts: Array[String] = [str(dice.pick(["Mr. Suresh Pandit, 62", "Mrs. Kamala Iyengar, 70", "Mr. Abdul Rashid, 58"])) +
		": left arm and leg weak, face drooping, speech slurred",
		("Woke up like this at 6 a.m. Last seen normal: 11 p.m. last night." if woke
			else "Symptoms started %s hours ago, at the dinner table" % _hours(hours)),
		"BP 178/96 · sugar 126 mg/dL",
		"CT head: %s" % ("bleeding in the brain" if bleed else "no bleed")]
	var window := not woke and hours <= 4.5 and not bleed
	var steps: Array = []
	steps.append(_step(dice, "s1", "Before the CT, one bedside test:", [_opt("sugar", "Blood sugar"), _opt("lipid", "Cholesterol"),
		_opt("echo", "An echo"), _opt("eeg", "An EEG")], "sugar",
		"Low sugar can look exactly like a stroke. It takes ten seconds to check. (It's 126: not the sugar.)"))
	steps.append(_step(dice, "s2", "Clot-busting drug (thrombolysis)?", [
		_opt("yes", "Yes: start it now"), _opt("no", "No"), _opt("later", "After an MRI tomorrow")], "yes" if window else "no",
		"Thrombolysis is for a stroke with no bleed, within 4.5 hours of when the patient was last seen normal. %s" %
			("A bleed: never." if bleed else ("Waking up with it means the clock started at bedtime." if woke
				else ("%s hours is inside the window." % _hours(hours) if window else "%s hours is too late." % _hours(hours))))))
	var bp_answer := "lower140" if bleed else ("under180" if window else "aspirin")
	steps.append(_step(dice, "s3", "And now:", [
		_opt("lower140", "Bring the top BP down towards 140"), _opt("under180", "Keep BP under 180/105 while the drug runs, and watch closely"),
		_opt("aspirin", "Aspirin 300 mg, once you know there's no bleed, and admit to the stroke unit"), _opt("home", "Home, with BP tablets")],
		bp_answer, {"lower140": "A bleed: bring the pressure down towards 140, and never aspirin.",
			"under180": "During thrombolysis the BP stays under 180/105, or the brain bleeds.",
			"aspirin": "Too late for thrombolysis and no bleed: aspirin, and the stroke unit."}[bp_answer]))
	return {"title": "The stroke clock", "card": "CASUALTY · RESUS", "facts": facts, "steps": steps}


static func _hours(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


# --- Chest pain: the ECG --------------------------------------------------------------------

static func _heart(dice: SeededRandom, level: String) -> Dictionary:
	var territory: String = dice.pick(["inferior", "anterior", "lateral"])
	var leads: String = {"inferior": "II, III and aVF", "anterior": "V1 to V4", "lateral": "I, aVL, V5 and V6"}[territory]
	var allergic: bool = level == "extreme" and dice.chance(0.4)
	var low_bp: bool = level != "easy" and dice.chance(0.5)
	var patient: String = dice.pick(["Mr. Rajendra Ghuge, 55, smoker", "Mr. Feroz Ansari, 61, diabetic", "Mrs. Lalita Jog, 66"])
	var tablet: bool = level != "easy" and not low_bp and patient.begins_with("Mr.") and dice.chance(0.4)
	var facts: Array[String] = [patient + ": crushing chest pain for an hour, sweating",
		"ECG: ST elevation in %s" % leads,
		"BP %s" % ("84/56" if low_bp else "138/86"),
		"Allergies: aspirin (the face swelled up last time)" if allergic else "Allergies: none known",
		"Took a 'strength tablet' (sildenafil) from the chemist last night" if tablet else "Medicines: BP tablet only"]
	var steps: Array = []
	steps.append(_step(dice, "s1", "Which part of the heart?", [_opt("inferior", "Inferior (the bottom)"),
		_opt("anterior", "Anterior (the front)"), _opt("lateral", "Lateral (the side)"), _opt("none", "None: the ECG is normal")],
		territory, "II, III and aVF look at the bottom of the heart; V1 to V4 the front; I, aVL, V5 and V6 the side."))
	steps.append(_step(dice, "s2", "The first drug:", [_opt("aspirin", "Aspirin 300 mg, chewed"),
		_opt("clopidogrel", "Clopidogrel 300 mg, no aspirin"), _opt("morphine", "Morphine first, for the pain"),
		_opt("statin", "A statin")], "clopidogrel" if allergic else "aspirin",
		"Aspirin 300 mg chewed, unless they're truly allergic: then clopidogrel alone." ))
	var no_gtn := low_bp or tablet
	steps.append(_step(dice, "s3", "GTN spray under the tongue for the pain?", [
		_opt("gtn", "Yes, one spray"), _opt("no", "No GTN")], "no" if no_gtn else "gtn",
		"GTN drops the blood pressure. Not with a top pressure under 90, and never within a day of sildenafil." if no_gtn
			else "Pressure fine, no sildenafil: GTN is safe for the pain."))
	return {"title": "Crushing chest pain", "card": "CASUALTY · ECG", "facts": facts, "steps": steps}


# --- A child with diarrhoea ---------------------------------------------------------------

static func _diarrhoea(dice: SeededRandom, level: String) -> Dictionary:
	var kinds := ["none", "some", "severe"]
	var kind: String = dice.pick(kinds)
	var months: int = dice.pick([4, 5, 9, 14, 20, 30]) if level != "easy" else dice.pick([14, 20, 30])
	var kg: int = 6 if months < 6 else (8 if months < 12 else (10 if months < 24 else 12))
	var signs: Array = {
		"none": ["Playing with the bed rails, alert", "Eyes normal", "Drinks normally", "Skin pinch goes back at once"],
		"some": ["Restless and irritable", "Eyes sunken", "Drinks eagerly, wants more", "Skin pinch goes back slowly"],
		"severe": ["Lethargic, hard to wake", "Eyes very sunken", "Not able to drink", "Skin pinch goes back very slowly (over 2 seconds)"]}[kind]
	var facts: Array[String] = ["Baby %s, %d months, %d kg" % [dice.pick(["Riya", "Arjun", "Fatima", "Kabir"]), months, kg],
		"Loose motions since yesterday, eight times. Grandmother has stopped all milk 'to rest the stomach'."]
	facts.append_array(signs)
	var steps: Array = []
	steps.append(_step(dice, "s1", "How dehydrated?", [_opt("none", "No dehydration"), _opt("some", "Some dehydration"),
		_opt("severe", "Severe dehydration")], kind,
		"Two signs from a row decide it. Lethargic, very sunken eyes, can't drink, pinch very slow: severe. Restless, sunken eyes, drinks eagerly, pinch slow: some."))
	var ors := 75 * kg
	var plan: Array
	var plan_answer: String
	match kind:
		"some":
			plan = _numbers(dice, ors, "ml of ORS over 4 hours, here", [ors * 2, ors / 2, 100 * kg])
			plan_answer = "n%d" % ors
		"none":
			plan = [_opt("a", "ORS at home after every loose stool, keep feeding"), _opt("iv", "IV fluids"),
				_opt("stop", "Stop milk and food till it settles"), _opt("antibiotic", "Antibiotics")]
			plan_answer = "a"
		_:
			plan = [_opt("c", "IV Ringer's lactate now, 100 ml per kg"), _opt("ors", "ORS by spoon"),
				_opt("a", "ORS at home"), _opt("antibiotic", "Antibiotics first")]
			plan_answer = "c"
	steps.append(_step(dice, "s2", "What now?" if kind != "some" else "Plan B: how much ORS in the first four hours?", plan,
		plan_answer, {"none": "No dehydration: Plan A. ORS after each stool at home, and keep feeding. Milk is food, not the problem.",
			"some": "Some dehydration: Plan B. 75 ml per kg of ORS over four hours: %d kg makes %d ml." % [kg, ors],
			"severe": "Severe: Plan C. IV Ringer's lactate, 100 ml per kg, starting now."}[kind]))
	var zinc := 10 if months < 6 else 20
	steps.append(_step(dice, "s3", "Zinc, for how long and how much?", [
		_opt("z%d" % zinc, "%d mg a day for 14 days" % zinc), _opt("z%d" % (30 - zinc), "%d mg a day for 14 days" % (30 - zinc)),
		_opt("three", "20 mg a day for 3 days"), _opt("none", "No zinc, it's not needed")], "z%d" % zinc,
		"Every child with diarrhoea gets zinc for 14 days: 10 mg under six months, 20 mg from six months. %d months: %d mg." % [months, zinc]))
	return {"title": "The baby with loose motions", "card": "CHILDREN'S CASUALTY", "facts": facts, "steps": steps}


# --- Burns: the rule of nines ---------------------------------------------------------------

const BODY := [["the whole right arm", 9], ["the whole left arm", 9], ["the front of the chest and belly", 18],
	["the whole back", 18], ["the whole right leg", 18], ["the whole left leg", 18], ["the head and neck", 9]]


static func _burns(dice: SeededRandom, level: String) -> Dictionary:
	var count := 2 if level == "easy" else 3
	var areas: Array = dice.shuffled(BODY).slice(0, count)
	var kg: int = dice.pick([50, 60, 70, 80])
	var red: int = -1 if level == "easy" else dice.next_int(count)
	var percent := 0
	var facts: Array[String] = [str(dice.pick(["Mrs. Sunita Wagh, 29", "Mr. Ganesh Kale, 41", "Mrs. Parveen Shaikh, 36"])) +
		", %d kg: kerosene stove burst, 40 minutes ago" % kg]
	for index in areas.size():
		var area: Array = areas[index]
		if index == red:
			facts.append("%s: red and painful, no blisters (like sunburn)" % _first_up(str(area[0])))
		else:
			facts.append("%s: blisters and raw skin" % _first_up(str(area[0])))
			percent += int(area[1])
	facts.append("Someone has put toothpaste on it. Of course they have.")
	var steps: Array = []
	steps.append(_step(dice, "s1", "How much of the body is burnt (for fluids)?", _numbers(dice, percent, "%",
		[percent + 9, percent - 9, percent + 18, percent + 1]), "n%d" % percent,
		"Rule of nines: each arm and the head 9, each leg, the front and the back 18. Red skin without blisters doesn't count." +
			(" Here: %d%%." % percent)))
	var first_eight := 2 * kg * percent
	steps.append(_step(dice, "s2", "Parkland: how much Ringer's lactate in the first 8 hours?", _numbers(dice, first_eight, "ml",
		[4 * kg * percent, kg * percent, 2 * kg * (percent + 9)]), "n%d" % first_eight,
		"4 ml × %d kg × %d%% = %s ml over 24 hours; half of it in the first 8 hours: %s ml." % [kg, percent, _grouped(4 * kg * percent),
			_grouped(first_eight)]))
	steps.append(_step(dice, "s3", "The toothpaste:", [_opt("water", "Wash it off and cool the burns under running tap water for 20 minutes"),
		_opt("ice", "Ice packs on the burns"), _opt("leave", "Leave it, it's soothing"), _opt("butter", "Butter, like the neighbour says")],
		"water", "Cool running water for 20 minutes helps for up to three hours after a burn. Ice, butter and toothpaste make it worse."))
	return {"title": "The kerosene stove", "card": "CASUALTY · BURNS", "facts": facts, "steps": steps}


static func _first_up(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


# --- Asthma: how bad, and what first --------------------------------------------------------

static func _asthma(dice: SeededRandom, level: String) -> Dictionary:
	var kinds := ["moderate", "severe"] if level == "easy" else ["moderate", "severe", "life"]
	var kind: String = dice.pick(kinds)
	var predicted: int = dice.pick([400, 450, 500])
	var share: float = {"moderate": dice.pick([0.6, 0.7]), "severe": dice.pick([0.4, 0.45]), "life": dice.pick([0.25, 0.3])}[kind]
	var peak := int(roundf(predicted * share / 10.0)) * 10
	# On extreme, a life-threatening attack can hide behind a decent oxygen level.
	var sneaky: bool = kind == "life" and level == "extreme" and dice.chance(0.5)
	var who: String = dice.pick(["Mr. Imran Qureshi, 24, college cricketer", "Ms. Divya Nair, 29, software tester",
		"Mr. Prakash Jadhav, 37, painter (the house kind)"])
	if _story:
		who = "Mr. Prakash Jadhav, 37, painter (the house kind)"
	var facts: Array[String] = [who + ": wheezy since the Diwali smoke last night, inhaler 'finished'",
		"Peak flow %d (best is %d)" % [peak, predicted],
		{"moderate": "Talks in full sentences, a bit breathless", "severe": "Can't finish a sentence in one breath",
			"life": "Quiet chest: hardly any wheeze to hear" if not sneaky else "Drowsy, and the wheeze has gone quiet"}[kind],
		{"moderate": "Breathing 22 a minute, pulse 98, oxygen 96%", "severe": "Breathing 28 a minute, pulse 118, oxygen 94%",
			"life": "Oxygen %d%%, pulse 124" % (94 if sneaky else 89)}[kind]]
	var steps: Array = []
	steps.append(_step(dice, "s1", "How bad is it?", [_opt("moderate", "Moderate"), _opt("severe", "Acute severe"),
		_opt("life", "Life-threatening"), _opt("anxiety", "Anxiety, mostly")], kind,
		"Peak flow over half of best and full sentences: moderate. A third to a half, can't finish a sentence, breathing 25 or more, pulse 110 or more: severe. Under a third, oxygen under 92%, a quiet chest or drowsy: life-threatening. Any one of those is enough." +
			(" A quiet chest is not a better chest." if kind == "life" else "")))
	var first := "spacer" if kind == "moderate" else "neb"
	steps.append(_step(dice, "s2", "First treatment:", [_opt("spacer", "Salbutamol inhaler through a spacer, up to 10 puffs"),
		_opt("neb", "Salbutamol 5 mg nebulised, driven by oxygen"), _opt("sedate", "Something to calm them down"),
		_opt("antibiotic", "IV antibiotics")], first,
		"Moderate: the inhaler through a spacer works as well as a nebuliser. Severe or worse: nebulised salbutamol on oxygen, back to back if needed. Never sedate an asthmatic."))
	var next := "icu" if kind == "life" else "steroid"
	steps.append(_step(dice, "s3", "And next?", [_opt("steroid", "Prednisolone 40 to 50 mg by mouth"),
		_opt("icu", "Steroids too, but add ipratropium and IV magnesium, and call ICU now"), _opt("xray", "Chest X-ray before anything else"),
		_opt("home", "Home with a new inhaler")], next,
		"Every attack bad enough to come in gets steroids. Life-threatening: add ipratropium and IV magnesium, and get ICU down before they tire out." ))
	return {"title": "The Diwali wheeze", "card": "CASUALTY · RESUS", "facts": facts, "steps": steps}


# --- A fit that won't stop ------------------------------------------------------------------

static func _seizure(dice: SeededRandom, level: String) -> Dictionary:
	var eclampsia: bool = level == "extreme" and dice.chance(0.35)
	if eclampsia:
		return _eclampsia(dice)
	var minutes: int = dice.pick([2, 6, 8]) if level != "easy" else dice.pick([6, 8])
	var low_sugar: bool = level != "easy" and dice.chance(0.3)
	var drip: bool = dice.chance(0.5)
	var facts: Array[String] = [str(dice.pick(["Mr. Ajay Bhosale, 31, known epileptic, 'forgot' his tablets for a week",
		"Mr. Nitin Rao, 45, diabetic, found fitting at the bus stop", "Ms. Farah Khan, 22, fitting in the college canteen"])),
		"Fitting for %d minutes, by the watch of the friend who brought them" % minutes,
		"Bedside sugar: %d mg/dL" % (38 if low_sugar else 112),
		"IV line: in, and working" if drip else "No IV line yet: the veins have gone into hiding"]
	var steps: Array = []
	var first := "dextrose" if low_sugar else ("drug" if minutes >= 5 else "time")
	steps.append(_step(dice, "s1", "What now?", [_opt("drug", "A benzodiazepine now"), _opt("time", "Keep them safe, time it: drugs at 5 minutes"),
		_opt("dextrose", "Glucose into the vein (or the gums)"), _opt("spoon", "A spoon between the teeth, hold the arms down")], first,
		{"dextrose": "A sugar of 38 is the cause: fix it first. No anticonvulsant stops a fit the sugar is causing.",
			"drug": "Five minutes or more is status epilepticus: drugs now.",
			"time": "Most fits stop by themselves. Protect the head, time it, and treat at 5 minutes."}[first] +
			" Nothing goes in the mouth, ever."))
	var drug := "lorazepam" if drip else "midazolam"
	steps.append(_step(dice, "s2", "The sugar is sorted if it was low, and it's still going at 5 minutes. First drug:", [_opt("lorazepam", "IV lorazepam 4 mg"),
		_opt("midazolam", "Buccal midazolam 10 mg, inside the cheek"), _opt("phenytoin", "Phenytoin first, it lasts longer"),
		_opt("oral", "Diazepam tablets")], drug,
		"With a line: IV lorazepam 4 mg. Without one: buccal midazolam 10 mg, no line needed. Phenytoin is second line, not first."))
	steps.append(_step(dice, "s3", "Two benzodiazepine doses later, still fitting:", [
		_opt("second", "Levetiracetam IV (60 mg/kg, up to 4.5 g), and call the anaesthetist"), _opt("third", "A third benzodiazepine dose"),
		_opt("wait", "Wait, it has to stop sometime"), _opt("haloperidol", "Haloperidol")], "second",
		"Two doses of benzodiazepine at most, then a second-line drug (levetiracetam, phenytoin or valproate), and the anaesthetist on the way. A third dose only stops the breathing."))
	return {"title": "The fit that won't stop", "card": "CASUALTY · RESUS", "facts": facts, "steps": steps}


static func _eclampsia(dice: SeededRandom) -> Dictionary:
	var facts: Array[String] = [str(dice.pick(["Mrs. Pinky Yadav, 23", "Mrs. Shabana Ansari, 27"])) + ", 34 weeks pregnant: fitting in the waiting room",
		"Fitting for 3 minutes. Her mother-in-law says it's 'the evil eye'.",
		"BP 172/112 · urine protein +++",
		"Swollen face and hands since last week, 'normal in pregnancy' said the neighbour"]
	var steps: Array = []
	steps.append(_step(dice, "s1", "What stops this fit?", [_opt("magnesium", "Magnesium sulphate: 4 g IV slowly, then a drip"),
		_opt("lorazepam", "IV lorazepam, like any fit"), _opt("phenytoin", "Phenytoin"), _opt("deliver", "Straight to theatre, mid-fit")],
		"magnesium", "Pregnant, high BP, protein in the urine and a fit: eclampsia. Magnesium sulphate stops it and stops the next one, better than any other drug."))
	steps.append(_step(dice, "s2", "The fit stops. BP still 170/110:", [_opt("labetalol", "IV labetalol, bring it down"),
		_opt("leave", "Leave it, she needs the pressure for the baby"), _opt("diuretic", "Furosemide"),
		_opt("fluids", "A litre of fluid, quickly")], "labetalol",
		"A top pressure of 160 or more risks a stroke: IV labetalol (or hydralazine). Fluids drown her lungs; she's already leaky."))
	steps.append(_step(dice, "s3", "The cure is:", [_opt("deliver", "Delivering the baby, once she's stable"),
		_opt("bedrest", "Bed rest till 40 weeks"), _opt("tablets", "BP tablets and home"), _opt("wait", "Wait for the next fit")], "deliver",
		"Eclampsia ends when the placenta comes out. Stabilise first, then deliver. Keep the magnesium going for 24 hours after."))
	return {"title": "The fit at 34 weeks", "card": "CASUALTY · LABOUR WARD CALLED", "facts": facts, "steps": steps}


# --- A head injury: the Glasgow coma scale, and who needs a CT ----------------------------------

const EYES := [[4, "open by themselves"], [3, "open when you speak"], [2, "open only to pain"], [1, "don't open"]]
const WORDS := [[5, "knows where they are and what day it is"], [4, "talking, but confused"],
	[3, "random words"], [2, "groans, no words"], [1, "no sound"]]
const MOVES := [[6, "obeys 'squeeze my hand'"], [5, "reaches for the pain"], [4, "pulls away from pain"],
	[3, "bends the arms to pain"], [2, "straightens the arms to pain"], [1, "no movement"]]


static func _head(dice: SeededRandom, level: String) -> Dictionary:
	var band: Array = {"easy": [0, 1], "hard": [0, 2], "extreme": [1, 3]}[level]
	var eyes: Array = EYES[dice.next_int_in(band[0], mini(band[1], 3))]
	var words: Array = WORDS[dice.next_int_in(band[0], mini(band[1] + 1, 4))]
	var moves: Array = MOVES[dice.next_int_in(band[0], mini(band[1] + 1, 5))]
	var gcs := int(eyes[0]) + int(words[0]) + int(moves[0])
	var vomits: int = dice.pick([0, 1, 3])
	var sign: String = dice.pick(["", "", "bruising round both eyes, like a panda", "clear fluid with blood dripping from one ear"]) \
		if level != "easy" else ""
	var warfarin: bool = level != "easy" and dice.chance(0.35)
	var facts: Array[String] = [str(dice.pick(["Mr. Rohan Shetty, 19: fell off a scooter, no helmet, 'just to the corner shop'",
		"Mr. Bhaskar Pawar, 66: slipped on the temple steps", "Ms. Tanvi Desai, 25: hit by an auto while looking at her phone"])),
		"Eyes: %s · Speech: %s" % [eyes[1], words[1]],
		"Movement: %s" % moves[1],
		"Vomited %s" % ["not at all", "once", "three times"][[0, 1, 3].find(vomits)]]
	if not sign.is_empty():
		facts.append("And: " + sign)
	facts.append("On warfarin for a heart valve" if warfarin else "No medicines")
	var steps: Array = []
	steps.append(_step(dice, "s1", "The Glasgow coma score:", _numbers(dice, gcs, "out of 15",
		[gcs + 1, gcs - 1, gcs + 2, gcs - 2, gcs - 3].filter(func(n: int) -> bool: return n >= 3 and n <= 15)),
		"n%d" % gcs, "Eyes %d + speech %d + movement %d = %d. Eyes out of 4, speech out of 5, movement out of 6." %
			[eyes[0], words[0], moves[0], gcs]))
	var urgent := gcs < 13 or vomits > 1 or not sign.is_empty()
	var ct := "hour" if urgent else ("eight" if warfarin else "none")
	steps.append(_step(dice, "s2", "A CT of the head?", [_opt("hour", "CT within the hour"), _opt("eight", "CT within 8 hours"),
		_opt("none", "No CT: watch them"), _opt("xray", "A skull X-ray instead")], ct,
		"CT within the hour for a score under 13, more than one vomit, signs of a skull-base fracture (panda eyes, fluid from the ear or nose), a fit or weakness. On blood thinners with none of those: CT within 8 hours. Skull X-rays miss bleeds. %s" %
			{"hour": "Here it's the hour.", "eight": "Here it's warfarin: within 8 hours.", "none": "Here: no CT needed."}[ct]))
	var then := "tube" if gcs <= 8 else ("home" if ct == "none" and gcs == 15 else "obs")
	steps.append(_step(dice, "s3", "Meanwhile:", [_opt("tube", "Protect the airway: anaesthetist, tube"),
		_opt("obs", "Neuro checks every half hour"), _opt("home", "Home with head-injury advice and a sensible adult"),
		_opt("sedate", "Sedate them so they lie still")], then,
		{"tube": "A score of 8 or less can't protect its own airway: tube it.",
			"obs": "Score and pupils every half hour; a drop of even one point means the CT, now.",
			"home": "Score 15, nothing worrying: home with written advice and someone to watch them overnight."}[then]))
	return {"title": "The bump on the head", "card": "CASUALTY · TRAUMA BAY", "facts": facts, "steps": steps}


# --- Poisoning: the pesticide, or the paracetamol ------------------------------------------------

static func _poison(dice: SeededRandom, level: String) -> Dictionary:
	if level != "easy" and dice.chance(0.45):
		return _paracetamol(dice, level)
	var facts: Array[String] = [str(dice.pick(["Mr. Shankar Gaikwad, 42, cotton farmer", "Mr. Lakhan Meena, 35, farm labourer"])) +
		": drank something from a bottle in the shed two hours ago",
		"Pupils tiny, like pinheads · drooling, sweating, wet everywhere",
		"Pulse %d · wheezing, chest full of crackles" % dice.pick([44, 48, 52]),
		"The family has brought the bottle. It has a picture of a beetle on it."]
	var steps: Array = []
	steps.append(_step(dice, "s1", "What has he taken?", [_opt("op", "An organophosphate pesticide"), _opt("alcohol", "Country liquor"),
		_opt("opioid", "Opium or heroin"), _opt("paraquat", "Paraquat weedkiller")], "op",
		"Tiny pupils plus drooling, sweating, a slow pulse and wet lungs is the cholinergic flood of an organophosphate. Opioids give tiny pupils but dry skin and slow breathing."))
	steps.append(_step(dice, "s2", "The antidote:", [_opt("double", "Atropine 1.8 to 3 mg IV, doubled every 5 minutes until he's dry"),
		_opt("once", "Atropine 0.6 mg once, and watch"), _opt("naloxone", "Naloxone"), _opt("vomit", "Salt water to make him vomit")],
		"double", "Atropine, lots of it: double the dose every five minutes until the chest is clear. Some patients need hundreds of milligrams. Never make them vomit: it goes into the lungs."))
	steps.append(_step(dice, "s3", "Enough atropine when:", [_opt("clear", "Chest clear, pulse over 80, top BP over 80, armpits dry"),
		_opt("pupils", "The pupils are big again"), _opt("three", "After three doses, whatever happens"), _opt("hr120", "The pulse hits 120")],
		"clear", "The targets are a clear chest, a pulse over 80, a top pressure over 80 and dry armpits. The pupils are the last thing to recover: chasing them overdoses the atropine."))
	return {"title": "The bottle from the shed", "card": "CASUALTY · RESUS", "facts": facts, "steps": steps}


static func _paracetamol(dice: SeededRandom, level: String) -> Dictionary:
	var kg: int = dice.pick([50, 55, 60, 70])
	var tablets: int = dice.pick([10, 20, 24, 30])
	var hours: int = dice.pick([2, 10]) if level == "hard" else dice.pick([2, 10, 10])
	var per_kg := tablets * 500 / kg
	var facts: Array[String] = [str(dice.pick(["Ms. Sneha Kulkarni, 19, second-year student", "Mr. Aditya Menon, 22, after a breakup"])) +
		", %d kg" % kg, "Swallowed %d paracetamol 500 mg tablets, %d hours ago" % [tablets, hours],
		"Feels fine. A bit sick. 'Can I go now?'", "Nothing else taken, says the friend. The friend is lying about the breakup."]
	var steps: Array = []
	steps.append(_step(dice, "s1", "How much, per kg?", _numbers(dice, per_kg, "mg/kg", [per_kg * 2, per_kg / 2, per_kg + 50]),
		"n%d" % per_kg, "%d × 500 mg = %d mg; ÷ %d kg = %d mg/kg. 150 mg/kg or more can kill the liver." % [tablets, tablets * 500, kg, per_kg]))
	var plan := "level" if hours < 4 else ("nac" if per_kg >= 150 else "level_now")
	steps.append(_step(dice, "s2", "What now?", [_opt("level", "A blood level at 4 hours, then decide"),
		_opt("nac", "Start acetylcysteine now, without waiting for the level"), _opt("level_now", "A level now, start if it's over the line"),
		_opt("home", "Feels fine: home")], plan,
		{"level": "Under 4 hours, a level means nothing yet: take it at 4 hours and use the treatment line.",
			"nac": "Over 8 hours and 150 mg/kg or more: start acetylcysteine now; it works best before 8 hours, and waiting costs liver.",
			"level_now": "A smaller dose after 8 hours: a level now, and treat if it's over the line."}[plan] + " Feeling fine means nothing: the liver fails on day three."))
	steps.append(_step(dice, "s3", "Before they go home:", [_opt("psych", "A mental-health review, kindly"),
		_opt("lecture", "A strong lecture"), _opt("police", "Inform the police"), _opt("nothing", "Nothing: the liver's fine")], "psych",
		"Every overdose gets a kind mental-health review before going home. A lecture has never stopped anyone."))
	return {"title": "The strip of tablets", "card": "CASUALTY · BAY 4", "facts": facts, "steps": steps}


# --- Sepsis: the score, the fluid, and the pressure ----------------------------------------------

static func _sepsis(dice: SeededRandom, level: String) -> Dictionary:
	var kg: int = dice.pick([50, 60, 70])
	var fast: bool = dice.chance(0.7)
	var low: bool = level != "easy" and dice.chance(0.6) or level == "easy" and dice.chance(0.5)
	var confused: bool = dice.chance(0.6)
	var lactate: float = dice.pick([1.6, 2.8, 4.6]) if level != "easy" else (4.6 if low else 1.6)
	var still_low: bool = level == "extreme" and low and dice.chance(0.6)
	var who: String = dice.pick(["Mrs. Shanti Kamble, 67", "Mr. Raghunath Joshi, 72", "Mrs. Meher Irani, 60"])
	if _story:
		who = "Mrs. Shanti Kamble, 67"
	var facts: Array[String] = [who +
		", %d kg: burning urine for three days, now shivering" % kg,
		"Breathing %d a minute · BP %s · temperature 39.4" % [26 if fast else 18, "86/50" if low else "124/78"],
		"Talking nonsense since morning, says the family" if confused else "Alert, cross, wants to go home",
		"Lactate %.1f" % lactate]
	var score := int(fast) + int(low) + int(confused)
	var steps: Array = []
	steps.append(_step(dice, "s1", "The quick sepsis score (qSOFA):", [_opt("n0", "0"), _opt("n1", "1"), _opt("n2", "2"), _opt("n3", "3")],
		"n%d" % score, "One point each for breathing 22 or faster, a top pressure of 100 or less, and confusion. Here: %d. Two or more: high risk." % score))
	var shocked := low or lactate >= 4.0
	var bolus := 30 * kg
	var fluid := "n%d" % bolus if shocked else "small"
	steps.append(_step(dice, "s2", "Fluids, after blood cultures and IV antibiotics within the hour:", [
		_opt("n%d" % bolus, "%s ml in the first 3 hours" % _grouped(bolus)), _opt("n%d" % (10 * kg), "%s ml in the first 3 hours" % _grouped(10 * kg)),
		_opt("small", "A 500 ml bolus, then reassess"), _opt("none", "No fluids: wait for the culture result")], fluid,
		("Low pressure or lactate 4 or more: 30 ml/kg, %d kg makes %s ml." % [kg, _grouped(bolus)]) if shocked
			else "Pressure fine and lactate under 4: a 500 ml bolus, then look again. Antibiotics never wait for the culture."))
	var after := "norad" if still_low else "watch"
	steps.append(_step(dice, "s3", "After the fluids, BP is %s:" % ("78/44" if still_low else "112/70"), [
		_opt("norad", "Noradrenaline, and ICU"), _opt("watch", "Urine output every hour, reassess often"),
		_opt("more", "Another 5 litres of fluid"), _opt("steroid", "Steroids first")], after,
		"Still low after the fluids is septic shock: noradrenaline to keep the average pressure over 65, in ICU. Better: measure the urine every hour and keep looking." if still_low
			else "Pressure back: urine every hour (half a ml per kg per hour at least) and reassess often. Drowning them in fluid helps nobody."))
	return {"title": "The shivering grandmother", "card": "CASUALTY · BED 6", "facts": facts, "steps": steps}


# --- Heat: stroke or exhaustion ----------------------------------------------------------------

static func _heat(dice: SeededRandom, level: String) -> Dictionary:
	var stroke: bool = dice.chance(0.55)
	var sweating: bool = not stroke or level == "extreme" and dice.chance(0.5)
	var temp: float = dice.pick([41.2, 40.8, 41.6]) if stroke else dice.pick([38.6, 39.1])
	var who: String = dice.pick(["Mr. Raju Pal, 38, construction worker", "Mr. Santosh Kale, 51, traffic constable",
		"Ms. Anjali Bhide, 27, marathon runner at noon (her idea)"])
	if _story:
		who = "Mr. Santosh Kale, 51, traffic constable"
	var facts: Array[String] = [who + ": collapsed in the May sun, 46 degrees outside",
		"Core temperature %.1f °C" % temp,
		("Confused, fighting the stretcher, then very sleepy" if stroke else "Awake, dizzy, headache, cramps in the legs"),
		("Still sweating" if sweating else "Skin hot and dry") + (" (sweating doesn't rule it out)" if stroke and sweating else "")]
	var steps: Array = []
	steps.append(_step(dice, "s1", "What is it?", [_opt("stroke", "Heat stroke"), _opt("exhaustion", "Heat exhaustion"),
		_opt("malaria", "Malaria"), _opt("drunk", "Drunk")], "stroke" if stroke else "exhaustion",
		"Heat stroke: core 40 or more AND a brain that isn't working (confused, fitting, unconscious). Heat exhaustion: hot, tired and dizzy, but thinking clearly." +
			(" Many heat stroke patients still sweat." if stroke and sweating else "")))
	steps.append(_step(dice, "s2", "Treatment:", [_opt("cool", "Cool hard and now: cold water, fans, ice packs at neck, armpits and groin"),
		_opt("shade", "Shade, lie down, ORS to drink"), _opt("paracetamol", "Paracetamol for the fever"),
		_opt("blanket", "A blanket for the shivering")], "cool" if stroke else "shade",
		"Heat stroke kills by the minute: cool first, transport later. Exhaustion: shade, rest and fluids. Paracetamol does nothing; this isn't a fever." ))
	steps.append(_step(dice, "s3", "Stop the active cooling at:", [_opt("t39", "39 °C, then keep watching"), _opt("t37", "37 °C"),
		_opt("t35", "35 °C, to be safe"), _opt("none", "No active cooling needed: shade and fluids")], "t39" if stroke else "none",
		"Stop at about 39 °C: the temperature keeps falling after you stop, and overshoot gives hypothermia." if stroke
			else "Exhaustion needs no ice bath. They go home tomorrow, and nowhere near the sun at noon."))
	return {"title": "Forty-six degrees", "card": "CASUALTY · COOLING BAY", "facts": facts, "steps": steps}
