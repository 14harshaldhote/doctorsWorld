class_name QuickCases
extends RefCounted
## The daily 60-second cases: six quick emergencies, each three questions
## whose answers come from facts rolled from the day's seed (the sugar
## reading, the child's weight, which leads have ST elevation, how many
## hours since the stroke began, where the burns are). Played with
## CrisisTask like the crises, against one clock for the whole case. Dr.
## Iyer coaches, with the lines under "quick" in story/crisis_lines.json.
##
## The rules are simplified from standard emergency teaching (Indian and
## WHO guidance) so the game teaches nothing wrong.

const IDS := ["quick_sugar", "quick_allergy", "quick_stroke", "quick_heart", "quick_diarrhoea", "quick_burns"]
const ACTOR := "iyer"


static func build(case_id: String, dice: SeededRandom, level: String) -> Dictionary:
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
