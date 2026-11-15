class_name ChiefDays
extends RefCounted
## The days after the story: the doctor runs the hospital. Days 29 to 35
## each bring one patient from the Chief's casebook (people the doctor has
## met before, mostly, now on the other side of the bed), a hard call that
## moves the hospital's standing (see Standing), and from Day 31 a staffing
## puzzle or a crash. From Day 36 the days go on for ever: a staffing rota
## or a major incident with a new seed every day, a teaching case on the
## simulator that gets harder every day, a hard call, and every fifth day the
## board's report on how the hospital is doing.
##
## It never levels off. Every ten generated days is a new tier: trouble in
## theatre hits harder, the puzzles stop coming easy, more days bring both
## a rota and a crash, the hospital loses a little ground every morning, and
## the board expects a better report. Milestone days (50, 75, 100, then
## every fiftieth) and personal records give the doctor something to reach.
##
## Beats use the Ward's keys (see Ward.DAYS and WardStory) plus
##   "casebook"  the casebook patient on the table (see casebook_setup)

const FIRST_DAY := 29
## From this day the casebook is closed and the days are generated.
const ROUNDS_FROM := 36
## Grace is back at her desk after her operation.
const GRACE_BACK := 42
## The board reports on Day 33, 38, 43...
const REPORT_EVERY := 5
## Each tier lasts this many days (Day 46 starts tier 1, Day 56 tier 2...).
const TIER_DAYS := 10
## Milestone days, then every MILESTONE_EVERY days after the last.
const MILESTONES := [50, 75, 100]
const MILESTONE_EVERY := 50
## The hardest trouble in theatre can hit (OperationTask's own limit).
const MOST_INTENSE := 2.0
## The hard calls after Day 38, one a day, never the same twice running.
const ROUNDS_CALLS := ["budget_month", "family_complaint", "staff_poach", "inspection"]

## Who is on the table each casebook day, by day.
const CASEBOOK_DAYS := {29: "banerjee", 30: "dev", 31: "tom", 32: "salim", 33: "mehra", 34: "verghese", 35: "grace"}
## The hard call each day before the generated ones.
const CALL_DAYS := {29: "night_nurses", 30: "dev_room", 31: "sponsor", 32: "reporter", 33: "mehra_first", 34: "kapoor_back",
	35: "grace_cover", 36: "intern_slip", 37: "monsoon_beds", 38: "rao_returns"}

## The casebook. Each patient's operation is one of the story's procedures
## with the patient swapped in (Procedures.for_patient):
##   procedure, patient (as the board reads it), first (as the team says
##   it), pronoun, age / age_words, wrong_age / wrong_age_words (the board's
##   misprint on a hard case), swaps (lines that belonged to the old patient)
##   team [lead, scrub nurse, anaesthetist or ""], op_flags, levels
##   arrive / bed   where they lie when admitted, and after
##   outfit        "patient" for staff who come in as patients
##   puzzle        [task, case, arrive talk, after talk, at] that day
##   call_first    the hard call comes before the operation
##   music         a beat's music ("emergency")
const CASEBOOK := {
	"banerjee": {
		"procedure": "wound", "patient": "Bela Banerjee", "first": "Mrs. Banerjee", "pronoun": "she",
		"age": "79", "age_words": "seventy-nine", "wrong_age": "97", "wrong_age_words": "ninety-seven",
		"swaps": [["She chops onions for a living.", "She knits for six grandchildren."],
			["She'll be chopping onions in ten days.", "She'll be knitting again in ten days."]],
		"team": ["iyer", "tom", ""], "levels": ["easy", "hard"],
		"op_flags": {"tetanus_known": "cb_banerjee_history_tetanus"},
		"arrive": "trolley:sit", "bed": "bed4:sit",
		"row": "Admissions: an old friend", "page": "Priya: Admissions. Mrs. Banerjee, from bed five, two years ago. She's asking for 'beta'.",
		"op_row": "Minor theatre: Mrs. Banerjee's arm", "op_page": "Priya: Minor theatre's free. Mrs. Banerjee says she's ready. She's brought biscuits.",
		"day_line": "Chief of Medicine · Your first full day",
		"end": [["op_banerjee_failed", "Mrs. Banerjee's arm is closed. Dr. Iyer finished it. She held your hand anyway."],
			["", "Mrs. Banerjee's arm is stitched. She knitted you a bookmark in recovery."]],
		"teaser": "Tomorrow: your first full day as Chief. Mrs. Banerjee is back, with a cut arm and a tin of biscuits.",
	},
	"dev": {
		"procedure": "appendix", "patient": "Dev Malhotra", "first": "Dev", "pronoun": "he",
		"age": "15", "age_words": "fifteen", "wrong_age": "51", "wrong_age_words": "fifty-one",
		"swaps": [["Dev, you can have your appendix in a jar.", "Dev, you can have your appendix in a jar. Your father will want a receipt."]],
		"put_back": [["malhotra", "bed4:chair"]],
		"team": ["iyer", "tom", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"allergy_known": "cb_dev_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "call_first": true,
		"row": "Admissions: Mr. Malhotra's son", "page": "Priya: Admissions. Mr. Malhotra's son. Pain low on the right. Mr. Malhotra is... also here.",
		"put": [["malhotra", "trolley:foot"]],
		"op_row": "Operate: Dev", "op_page": "Priya: Theatre 2 is ready for Dev. His father has asked the porter for your mobile number.",
		"day_line": "Chief of Medicine · A father in the corridor",
		"end": [["op_dev_failed", "Dev's appendix is out. Dr. Iyer finished it. Mr. Malhotra shook your hand. Twice."],
			["", "Dev's appendix is in a jar. Mr. Malhotra has asked for a copy of the invoice. For the jar."]],
		"teaser": "Tomorrow: Mr. Malhotra's son has a pain low on the right. Mr. Malhotra has a list of demands.",
	},
	"tom": {
		"procedure": "hernia", "patient": "Tom D'Souza", "first": "Tom", "pronoun": "he",
		"age": "41", "age_words": "forty-one", "wrong_age": "14", "wrong_age_words": "fourteen",
		"swaps": [["He lays bricks for a living; make it strong.", "He lifts instrument trays for a living; make it strong."],
			["He'll be back on the scaffolding in six weeks.", "He'll be back at the ring in six weeks."],
			["paratha", "samosa"]],
		"team": ["iyer", "neha", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"ate_known": "cb_tom_history_meal", "allergy_asked": "cb_tom_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "outfit": "patient",
		"row": "Admissions: one of your own", "page": "Priya: Admissions. It's Tom. He says it's nothing. He's holding his groin and not breathing much.",
		"op_row": "Operate: Tom", "op_page": "Neha: Theatre 2. I'm scrubbing for Tom. He's already told me where I keep everything wrong.",
		"puzzle": ["rota", "chief_rota", "cb_tom_rota_arrive", "chief_rota_after", 16 * 60 + 30],
		"day_line": "Chief of Medicine · The scrub nurse is the patient",
		"end": [["op_tom_failed", "Tom's hernia is mended. Dr. Iyer finished it. He's already criticising the tray."],
			["chief_rota_gap", "Tom's hernia is mended. Tonight's rota has a hole in it."],
			["", "Tom's hernia is mended. Neha says theatre was very quiet without him. Too quiet."]],
		"teaser": "Tomorrow: Tom has handed you instruments for years. Tomorrow he's on the table.",
	},
	"salim": {
		"procedure": "spleen", "patient": "Salim Sheikh", "first": "Salim", "pronoun": "he",
		"age": "36", "age_words": "thirty-six", "wrong_age": "63", "wrong_age_words": "sixty-three",
		"swaps": [["Dr. Sethi had to take over.", "Dr. Iyer had to take over."],
			["People who fall off scaffolds rarely break one thing.", "People who come off motorbikes rarely break one thing."],
			["where he landed on the scaffold", "where he hit the divider"],
			["he's twenty-four and he'll cough", "he's thirty-six and he'll cough"],
			["At two in the morning. Go and tell his wife.", "Before lunch, too. Go and tell his daughter."],
			["at two in the morning", "in broad daylight"]],
		"team": ["iyer", "tom", "khan"], "levels": ["hard", "extreme"],
		"op_flags": {"allergy_asked": "cb_salim_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "music": "emergency",
		"row": "Admissions: a rider from the crash", "page": "Priya: The last one off the ambulances. A delivery rider. He says he knows you.",
		"op_row": "Operate: Salim", "op_page": "Dr. Iyer: Theatre 1, now. His pressure's going. Bring your hands.",
		"puzzle": ["triage", "chief_triage", "cb_salim_triage_arrive", "chief_triage_after", 9 * 60 + 5],
		"day_line": "Major incident · The toll plaza",
		"end": [["op_salim_failed", "Salim is alive. Dr. Iyer finished it. Pooja is asleep in the chair by his bed."],
			["chief_triage_under", "Salim is alive. One of the crash waited who shouldn't have."],
			["", "Salim is alive, minus a spleen or a tear, and plus a daughter who won't let go of his hand."]],
		"teaser": "Tomorrow: a bus, a toll plaza and a row of motorbikes. One of the riders is someone you know.",
	},
	"mehra": {
		"procedure": "hip", "patient": "Kamala Mehra", "first": "Mrs. Mehra", "pronoun": "she",
		"age": "79", "age_words": "seventy-nine", "wrong_age": "59", "wrong_age_words": "fifty-nine",
		"swaps": [["her son's wedding in March", "her grandson's wedding in March"], ["eighty-one", "seventy-nine"],
			["Warfarin, stopped yesterday, with vitamin K. Her clotting this morning is 1.4.",
				"Warfarin, last dose last night. Vitamin K went in at breakfast. Her clotting's down to 1.4."],
			["You checked her chart yourself. Warfarin, stopped.", "You asked her yourself. Warfarin, last night."],
			["You knew her warfarin had been stopped and told the team.", "You knew about her warfarin and told the team."]],
		"team": ["bhatt", "tom", "khan"], "levels": ["hard", "extreme"],
		"op_flags": {"warfarin_known": "cb_mehra_history_medicines", "allergy_known": "cb_mehra_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "outfit": "patient", "call_first": true,
		"row": "Admissions: a board member's mother", "page": "Priya: Admissions. Mrs. Mehra, a broken hip, and three phone calls from her son already.",
		"op_row": "Operate: Mrs. Mehra's hip", "op_page": "Dr. Bhatt: Theatre 3's mine, the hip is yours. Bring the X-rays and your patience.",
		"day_line": "Board day · A broken hip at breakfast",
		"end": [["op_mehra_failed", "Mrs. Mehra's hip is fixed. Dr. Bhatt finished it. Her son has rung the board."],
			["hc_mehra_first_queue", "Both hips are fixed. Mrs. Mehra's was second. She's furious, and fine."],
			["", "Mrs. Mehra's hip is fixed. She'll walk into her grandson's wedding. Slowly, and talking."]],
		"teaser": "Tomorrow: a board member's mother breaks her hip at breakfast. The board report is at four.",
	},
	"verghese": {
		"procedure": "bile_leak", "patient": "Anjali Verghese", "first": "Mrs. Verghese", "pronoun": "she",
		"age": "47", "age_words": "forty-seven", "wrong_age": "74", "wrong_age_words": "seventy-four",
		"swaps": [["Saturday's three holes", "the three CarePlus holes"], ["one more than Saturday", "one more than CarePlus used"],
			["Dr. Sethi's notes said two last time.", "The CarePlus notes said two last time."],
			["The board named Saturday's operation.", "The board named her CarePlus operation."],
			["complaining by Sunday", "complaining by the weekend"], ["she goes home Sunday", "she goes home in three days"]],
		"team": ["iyer", "tom", "khan"], "levels": ["hard", "extreme"],
		"op_flags": {"allergy_known": "cb_verghese_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "call_first": true,
		"row": "Admissions: a CarePlus day case", "page": "Priya: Admissions. A day case from CarePlus, three days ago. Fever, and a belly like a board. Sound familiar?",
		"op_row": "Operate: Mrs. Verghese", "op_page": "Dr. Iyer: Theatre 2 at two. Same leak, different hospital. Sound familiar?",
		"puzzle": ["rota", "chief_rota", "cb_verghese_rota_arrive", "chief_rota_after", 16 * 60 + 30],
		"day_line": "Chief of Medicine · CarePlus sends you a patient",
		"end": [["op_verghese_failed", "Mrs. Verghese is washed out and dry. Dr. Iyer finished it."],
			["hc_kapoor_back_report", "Mrs. Verghese is dry. Your letter to the medical council went at six."],
			["", "Mrs. Verghese is dry, and asleep. Grace went home at noon. Grace never goes home."]],
		"teaser": "Tomorrow: a CarePlus day case comes to your door with a belly full of bile. Dr. Kapoor follows.",
	},
	"grace": {
		"procedure": "gallbladder", "patient": "Grace Mathew", "first": "Grace", "pronoun": "she",
		"age": "56", "age_words": "fifty-six", "wrong_age": "65", "wrong_age_words": "sixty-five",
		"swaps": [],
		"team": ["iyer", "neha", "khan"], "levels": ["hard", "extreme"],
		"op_flags": {"aspirin_known": "cb_grace_history_medicines", "allergy_asked": "cb_grace_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "outfit": "patient", "partner": "priya",
		"row": "Admissions: Sister Grace", "page": "Priya: Admissions. Doctor... it's Grace. She told me not to page you. I'm paging you.",
		"op_row": "Operate: Sister Grace", "op_page": "Neha: Theatre 2. We're all here. Nobody asked to be. Nobody would miss it.",
		"day_line": "Chief of Medicine · The head nurse is on the list",
		"end": [["op_grace_failed", "Grace's gallbladder is out. Dr. Iyer finished it. Grace says she'll audit the notes."],
			["", "Grace's gallbladder is out. She has asked for the stones, a pen, and the night rota."]],
		"teaser": "Tomorrow: Sister Grace has been hiding a pain for a month. Tomorrow she can't.",
	},
}

## The hard calls: where they happen and with whom.
##   row, go, with, page, put, put_end, at, teaser (for the generated days)
const CALLS := {
	"night_nurses": {"row": "Mr. Malhotra's budget", "go": "desk", "with": "malhotra", "at": 16 * 60,
		"page": "Grace: Mr. Malhotra's at my desk with the budget. I'm staying. Somebody has to.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]]},
	"dev_room": {"row": "Mr. Malhotra wants a room", "go": "desk", "with": "malhotra",
		"page": "Priya: Mr. Malhotra at the desk. He's asking about the side room. Mrs. Chawla is in the side room.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]]},
	"sponsor": {"row": "A sponsor for the day unit", "go": "desk", "with": "malhotra", "at": 15 * 60 + 30,
		"page": "Mr. Malhotra: Chief, two minutes? A drug company wants to pay for something. Smile.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]]},
	"reporter": {"row": "The cameras at the door", "go": "desk", "with": "malhotra", "at": 16 * 60 + 30,
		"page": "Mr. Malhotra: There's a television van outside. They want the doctor from the crash. That's you.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]]},
	"mehra_first": {"row": "Two hips, one theatre", "go": "desk", "with": "malhotra", "at": 11 * 60,
		"page": "Mr. Malhotra: Chief. Desk. Suresh Mehra has called the board, the Dean and me. In that order.",
		"put": [["malhotra", "desk:left"], ["bhatt", "desk:far"]], "put_end": [["malhotra", "off"], ["bhatt", "off"]]},
	"kapoor_back": {"row": "Dr. Kapoor comes to collect", "go": "desk", "with": "kapoor",
		"page": "Priya: Dr. Kapoor's at the desk. He's brought flowers for Mrs. Verghese and a form for you.",
		"put": [["kapoor", "desk:left"]], "put_end": [["kapoor", "off"]]},
	"grace_cover": {"row": "Grace's floor", "go": "bed4", "with": "grace", "at": 17 * 60,
		"page": "Priya: Grace is awake. She's asking who's running her floor. She's asking quite loudly.",
		"put": [["priya", "bed4:other"]], "put_end": [["priya", "off"]]},
	"intern_slip": {"row": "Dr. Saxena's mistake", "go": "desk", "with": "saxena", "at": 15 * 60,
		"page": "Dr. Saxena: Chief, can I talk to you? Not on the pager. In person.",
		"put": [["saxena", "desk:left"]], "put_end": [["saxena", "off"]],
		"teaser": "your intern wants a word. Not on the pager."},
	"monsoon_beds": {"row": "Fever season", "go": "desk", "with": "malhotra", "at": 15 * 60,
		"page": "Mr. Malhotra: Desk, Chief. Every bed in the building is full of dengue and we have a list of forty operations.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]],
		"teaser": "the monsoon fevers have filled every bed in the building."},
	"rao_returns": {"row": "An old friend asks", "go": "desk", "with": "rao", "at": 15 * 60,
		"page": "Grace: There's a retired man at my desk asking for 'the Chief'. He's brought his own stethoscope.",
		"put": [["rao", "desk:left"]], "put_end": [["rao", "off"]],
		"teaser": "a retired man asks for the Chief. He's brought his own stethoscope."},
	"budget_month": {"row": "The monthly budget", "go": "desk", "with": "malhotra", "at": 16 * 60,
		"page": "Mr. Malhotra: The monthly budget, Chief. One pen, three columns, not enough money.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]],
		"teaser": "Mr. Malhotra brings the monthly budget, and one pen."},
	"family_complaint": {"row": "A family at the desk", "go": "desk", "with": "relative", "at": 16 * 60,
		"page": "Priya: A family at the desk. A complaint, and a lawyer's business card. They want the Chief.",
		"put": [["priya", "desk:far"], ["relative", "desk:left"]], "put_end": [["relative", "off"], ["priya", "off"]],
		"teaser": "a family at the desk with a complaint and a lawyer's card."},
	"staff_poach": {"row": "CarePlus wants Priya", "go": "desk", "with": "priya", "at": 16 * 60,
		"page": "Priya: Doctor, have you got a minute? It's about a letter. From CarePlus.",
		"put": [["priya", "desk:left"]], "put_end": [["priya", "off"]],
		"teaser": "CarePlus wants one of your nurses, and they're offering double."},
	"inspection": {"row": "The inspectors", "go": "desk", "with": "priya", "at": 9 * 60 + 30,
		"page": "Priya: The inspectors are here. Unannounced. Which means they rang at seven.",
		"put": [["priya", "desk:far"], ["malhotra", "desk:left"]], "put_end": [["malhotra", "off"], ["priya", "off"]],
		"teaser": "the health inspectors, unannounced, which means they'll ring at seven."},
}

## The hard calls' flags, so a day played again starts clean.
const CALL_FLAGS := {
	"night_nurses": ["hc_night_nurses_two", "hc_night_nurses_agency", "hc_night_nurses_trip"],
	"dev_room": ["hc_dev_room_bay", "hc_dev_room_side", "hc_dev_room_ask"],
	"sponsor": ["hc_sponsor_all", "hc_sponsor_money", "hc_sponsor_no"],
	"reporter": ["hc_reporter_film", "hc_reporter_statement", "hc_reporter_no"],
	"mehra_first": ["hc_mehra_first_queue", "hc_mehra_first_vip", "hc_mehra_first_both"],
	"kapoor_back": ["hc_kapoor_back_report", "hc_kapoor_back_call", "hc_kapoor_back_quiet"],
	"grace_cover": ["hc_grace_cover_priya", "hc_grace_cover_agency", "hc_grace_cover_grace"],
	"intern_slip": ["hc_intern_slip_report", "hc_intern_slip_quiet", "hc_intern_slip_nights"],
	"monsoon_beds": ["hc_monsoon_beds_cancel", "hc_monsoon_beds_seminar", "hc_monsoon_beds_careplus"],
	"rao_returns": ["hc_rao_returns_teach", "hc_rao_returns_clinic", "hc_rao_returns_no"],
	"budget_month": ["hc_budget_month_nurses", "hc_budget_month_kit", "hc_budget_month_clinic"],
	"family_complaint": ["hc_family_complaint_sorry", "hc_family_complaint_defend", "hc_family_complaint_review"],
	"staff_poach": ["hc_staff_poach_match", "hc_staff_poach_promote", "hc_staff_poach_go"],
	"inspection": ["hc_inspection_real", "hc_inspection_tidy", "hc_inspection_delay"],
}

## The puzzles on the generated days: [task, case, arrive talk, after talk].
const ROUNDS_PUZZLES := {
	"rota": ["rota", "chief_rota", "rounds_rota_arrive", "chief_rota_after"],
	"triage": ["triage", "chief_triage", "rounds_triage_arrive", "chief_triage_after"],
}
const PUZZLE_TEASERS := {
	"rota": "four nurses off sick, and every bed needs a name by eight.",
	"triage": "the highway again. The ambulances are already queuing.",
}


static func is_chief_day(day: int) -> bool:
	return day >= FIRST_DAY


static func is_report_day(day: int) -> bool:
	return day > DayHooks.LAST_STORY_DAY and (day - DayHooks.LAST_STORY_DAY) % REPORT_EVERY == 0


## Days from day to the next board report after it (5 on a report day).
static func days_to_report(day: int) -> int:
	var next := day + 1
	while not is_report_day(next):
		next += 1
	return next - day


## The casebook patient on a day, or "".
static func patient_for(day: int) -> String:
	return str(CASEBOOK_DAYS.get(day, ""))


## The hard call on a day: written for Days 29 to 38, then one of the
## generated ones, never yesterday's.
static func call_for(profile: PlayerProfile, day: int) -> String:
	if CALL_DAYS.has(day):
		return str(CALL_DAYS[day])
	if day < FIRST_DAY:
		return ""
	var yesterday := call_for(profile, day - 1) if day - 1 > 38 else ""
	var options: Array = ROUNDS_CALLS.filter(func(id: String) -> bool: return id != yesterday)
	return str(SeededRandom.new(_seed(profile, day, "call")).pick(options))


## The puzzle on a generated day: a staffing rota most days, a major
## incident every fourth.
static func rounds_puzzle(day: int) -> String:
	return "triage" if (day - ROUNDS_FROM) % 4 == 3 else "rota"


## How far into the endless days: 0 until Day 45, 1 from Day 46, and one
## more every ten days after, for ever.
static func tier(day: int) -> int:
	if day < ROUNDS_FROM:
		return 0
	return (day - ROUNDS_FROM) / TIER_DAYS


## True on the first day of a new tier.
static func tier_starts(day: int) -> bool:
	return day > ROUNDS_FROM and (day - ROUNDS_FROM) % TIER_DAYS == 0


## A busy day brings both a rota and a crash. None in tier 0; then more of
## them each tier, up to four days in five.
static func busy_day(profile: PlayerProfile, day: int) -> bool:
	var level := tier(day)
	if level <= 0 or not patient_for(day).is_empty():
		return false
	var odds := minf(0.2 + 0.15 * float(level - 1), 0.8)
	return SeededRandom.new(_seed(profile, day, "busy")).chance(odds)


## The difficulties a generated day's puzzle may roll: no easy ones after
## tier 0, only the hardest from tier 2.
static func puzzle_levels(day: int) -> Array:
	match mini(tier(day), 2):
		0:
			return ["easy", "hard", "extreme"]
		1:
			return ["hard", "extreme"]
	return ["extreme"]


## The simulator's difficulties: hard or extreme, only extreme from tier 1.
static func sim_levels(day: int) -> Array:
	return ["hard", "extreme"] if tier(day) <= 0 else ["extreme"]


## How much more the board expects at a report, by tier.
static func board_bar(day: int) -> int:
	return mini(tier(day) * 8, 60)


## How much ground the hospital loses each morning of the generated days.
static func drift(day: int) -> int:
	if day <= ROUNDS_FROM:
		return 0
	return mini(1 + tier(day) / 3, 3)


## The meter the morning's drift takes from: staff, money, public, in turn.
static func drift_meter(day: int) -> String:
	return str(Standing.METERS[day % Standing.METERS.size()])


static func is_milestone(day: int) -> bool:
	if day in MILESTONES:
		return true
	var last: int = MILESTONES[MILESTONES.size() - 1]
	return day > last and (day - last) % MILESTONE_EVERY == 0


## The next milestone after day.
static func next_milestone(day: int) -> int:
	var next := day + 1
	while not is_milestone(next):
		next += 1
	return next


## The casebook case loaded into the simulator on a generated day.
static func sim_for(profile: PlayerProfile, day: int) -> String:
	var ids: Array = CASEBOOK.keys()
	ids.sort()
	var yesterday := sim_for(profile, day - 1) if day - 1 >= ROUNDS_FROM else ""
	var options := ids.filter(func(id: String) -> bool: return id != yesterday)
	return str(SeededRandom.new(_seed(profile, day, "sim")).pick(options))


static func _seed(profile: PlayerProfile, day: int, what: String) -> int:
	return absi(hash("%s|%d|%s" % [profile.name, day, what])) % 1000003 + 1


## Who runs the morning with the doctor.
static func partner(day: int) -> String:
	if day >= ROUNDS_FROM:
		return "iyer"
	var id := patient_for(day)
	return str((CASEBOOK.get(id, {}) as Dictionary).get("partner", "grace"))


## True while Grace is off after her operation (she comes back on Day 42).
static func grace_away(day: int) -> bool:
	return day >= ROUNDS_FROM and day < GRACE_BACK


## How much harder trouble in theatre hits on a Chief's day: more each day,
## and more again when the staff are stretched thin.
static func intensity(profile: PlayerProfile, day: int) -> float:
	var level := 1.0 + clampf(float(day - DayHooks.LAST_STORY_DAY) * 0.03, 0.0, 0.45) + 0.05 * float(tier(day))
	if Standing.is_low(profile, "staff"):
		level += 0.12
	return minf(level, MOST_INTENSE)


## The day's beats.
static func beats(profile: PlayerProfile, day: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var id := patient_for(day)
	if not id.is_empty():
		var entry: Dictionary = CASEBOOK[id]
		found.append({"id": "morning", "talk": "cb_%s_morning" % id, "with": partner(day)})
		var puzzle: Array = entry.get("puzzle", [])
		if not puzzle.is_empty() and str(puzzle[0]) == "triage":
			found.append(_puzzle_beat(puzzle))
		var call := _call_beat(call_for(profile, day), day)
		var admit := {"id": "patient", "row": str(entry["row"]), "go": "trolley", "talk": "cb_%s_arrive" % id, "with": id,
			"page": str(entry["page"]), "at": 9 * 60 + 30 if puzzle.is_empty() or str(puzzle[0]) != "triage" else 11 * 60,
			"put": [[id, str(entry["arrive"])], ["priya", "trolley:other"]] + (entry.get("put", []) as Array),
			"tasks": [["history", "cb_%s_history" % id]], "after": "cb_%s_after" % id,
			"put_end": [[id, str(entry["bed"])], ["priya", "off"]] + _offs(entry.get("put", []))}
		if entry.has("music"):
			admit["music"] = entry["music"]
		found.append(admit)
		if bool(entry.get("call_first", false)):
			found.append(call)
		found.append(_op_beat(profile, id, entry))
		if not bool(entry.get("call_first", false)):
			found.append(call)
		if not puzzle.is_empty() and str(puzzle[0]) != "triage":
			found.append(_puzzle_beat(puzzle))
	else:
		found.append({"id": "morning", "talk": "rounds_morning", "with": "iyer"})
		var kinds := ["rota", "triage"] if busy_day(profile, day) else [rounds_puzzle(day)]
		for kind: String in kinds:
			var puzzle: Array = (ROUNDS_PUZZLES[kind] as Array).duplicate()
			puzzle.append(9 * 60 + 5 if kind == "triage" else 8 * 60)
			var beat := _puzzle_beat(puzzle)
			beat["levels"] = puzzle_levels(day)
			found.append(beat)
		found.append(_sim_beat(profile, day))
		found.append(_call_beat(call_for(profile, day), day))
	if is_report_day(day):
		found.append({"id": "report", "row": "The board's report", "where": "seminar", "at": 17 * 60,
			"card": ["Seminar room · 17:00", "Mrs. Rajan has your numbers. So does Mr. Malhotra. So, somehow, does the newspaper."],
			"talk": "board_report", "with": "rajan", "slide": "BOARD REPORT\nChief of Medicine",
			"put": [["rajan", "seminar:head"], ["malhotra", "seminar:seat1"], ["iyer", "seminar:seat2"], ["you", "seminar:seat5"]]})
	return found


static func _offs(puts: Array) -> Array:
	var offs := []
	for put: Array in puts:
		offs.append([put[0], "off"])
	return offs


static func _puzzle_beat(puzzle: Array) -> Dictionary:
	var task := str(puzzle[0])
	var beat := {"id": task, "talk": str(puzzle[2]), "with": "priya", "coach": "priya", "tasks": [[task, str(puzzle[1])]],
		"after": str(puzzle[3]), "levels": ["easy", "hard", "extreme"], "at": int(puzzle[4])}
	if task == "triage":
		beat.merge({"row": "The ambulance bay: sort the casualties", "go": "trolley", "music": "emergency",
			"page": "Priya: AMBULANCE BAY. NOW. The first ones are off.",
			"put": [["priya", "trolley:other"], ["bg3", "trolley:lie"]], "put_end": [["priya", "off"], ["bg3", "bed6:lie"]]})
	else:
		beat.merge({"row": "Tonight's cover with Priya", "go": "desk",
			"page": "Priya: Desk, when you can. Four off sick, and the night shift starts at eight.",
			"put": [["priya", "desk:left"]], "put_end": [["priya", "off"]]})
	return beat


## A call's beat. "relative" stands for whichever family is at the desk
## today: one of three, by the day's small story (rounds_a, b or c).
static func _call_beat(call: String, day: int) -> Dictionary:
	var data: Dictionary = CALLS[call]
	var family := "relative_" + "abc"[day % 3]
	var swap := func(puts: Array) -> Array:
		var made := []
		for put: Array in puts:
			made.append([family if str(put[0]) == "relative" else put[0], put[1]])
		return made
	var with := str(data["with"])
	var beat := {"id": "call", "row": str(data["row"]), "go": str(data["go"]), "talk": "hc_" + call,
		"with": family if with == "relative" else with, "page": str(data["page"]),
		"put": swap.call(data.get("put", [])), "put_end": swap.call(data.get("put_end", []))}
	if data.has("at"):
		beat["at"] = int(data["at"])
	return beat


static func _op_beat(profile: PlayerProfile, id: String, entry: Dictionary) -> Dictionary:
	var team: Array = entry["team"]
	var lead := str(team[0])
	var beat := {"id": "op", "row": str(entry["op_row"]), "go": "bed4", "talk": "cb_%s_ready" % id, "with": id,
		"page": str(entry["op_page"]), "at": 13 * 60 + 50, "tasks": [["operate", str(entry["procedure"])]],
		"team": team, "patient": id, "casebook": id, "op_flags": entry.get("op_flags", {}), "levels": entry["levels"],
		"put_back": [[id, str(entry["bed"])], ["you", "bed4:side"], [lead, "bed4:foot"]] + (entry.get("put_back", []) as Array),
		"after": "cb_%s_after_op" % id, "put_end": [[lead, "off"]] + _offs(entry.get("put_back", []))}
	if entry.has("music"):
		beat["music"] = entry["music"]
	return beat


static func _sim_beat(profile: PlayerProfile, day: int) -> Dictionary:
	var id := sim_for(profile, day)
	var entry: Dictionary = CASEBOOK[id]
	return {"id": "sim", "row": "Teach the interns: the simulator", "go": "lightbox", "talk": "sim_arrive", "with": "saxena",
		"page": "Dr. Saxena: The simulator's loaded with one of last month's cases. The new interns are behind the glass. No pressure.",
		"at": 13 * 60 + 30, "put": [["saxena", "lightbox:left"]], "tasks": [["operate", str(entry["procedure"])]],
		"brief": "sim_brief", "team": ["iyer", "neha", "khan"], "patient": "sim", "casebook": id, "sim": true,
		"levels": sim_levels(day), "put_back": [["you", "lightbox"], ["saxena", "lightbox:left"]],
		"after": "sim_after", "put_end": [["saxena", "off"]]}


## Where everyone is as the day starts: the head nurse behind the desk
## (Priya on Grace's own day and while Grace is off), Dr. Iyer beside it.
static func staging(day: int) -> Array:
	var puts := [["bg1", "bed1:lie"], ["bg2", "bed3:lie"], ["bg3", "bed6:lie"], ["you", "desk"]]
	var nurse := "priya" if patient_for(day) == "grace" or grace_away(day) else "grace"
	puts.append([nurse, "desk:behind"])
	puts.append(["iyer", "desk:right"])
	return puts


## The outfit a casebook patient arrives in ("" to keep their own).
static func outfit(day: int) -> String:
	return str((CASEBOOK.get(patient_for(day), {}) as Dictionary).get("outfit", ""))


## What the case on the table changes in the procedure (Procedures.for_patient).
static func casebook_setup(id: String, sim: bool = false) -> Dictionary:
	var entry: Dictionary = CASEBOOK.get(id, {})
	if entry.is_empty():
		return {}
	var patient := str(entry["patient"])
	var made := {
		"patient": patient, "first": str(entry["first"]), "pronoun": str(entry["pronoun"]),
		"swaps": (entry.get("swaps", []) as Array).duplicate(true),
		"timeout": {"patient": {
			"reads": "%s, %s" % [patient, entry["age"]], "said": "Patient: %s, %s." % [patient, entry["age_words"]],
			"wrong_reads": "%s, %s" % [patient, entry["wrong_age"]],
			"wrong_said": "Patient: %s, %s." % [patient, entry["wrong_age_words"]],
		}},
	}
	var lead := str((entry["team"] as Array)[0])
	if lead != "iyer" and lead != "bhatt":
		made["lead"] = lead
	if sim:
		made["theatre"] = "Simulation lab"
		made["end_lines"] = {"won": "Clean run. The interns are clapping behind the glass. Don't let it go to your head.",
			"struggled": "You got there. The interns saw every wobble. That's what a simulator is for.",
			"failed": "It's done. Reset it. Again."}
		made["outcome_lines"] = {"won": "A clean run, in front of the interns.", "struggled": "Through it, wobbles and all.",
			"failed": "The simulator won this one."}
	return made


## The line under the day's card.
static func day_line(profile: PlayerProfile, day: int) -> String:
	var id := patient_for(day)
	if not id.is_empty():
		return str(CASEBOOK[id]["day_line"])
	if is_milestone(day):
		return "Day %d · A milestone" % day
	if is_report_day(day):
		return "Chief of Medicine · Board report at five"
	if busy_day(profile, day):
		return "Chief of Medicine · A rota and a crash"
	return "Chief of Medicine · %s" % ("Major incident" if rounds_puzzle(day) == "triage" else "Day %d in the chair" % (day - DayHooks.LAST_STORY_DAY))


## The day's last line.
static func end_line(profile: PlayerProfile, day: int) -> String:
	var id := patient_for(day)
	var line := ""
	if not id.is_empty():
		for option: Array in CASEBOOK[id]["end"]:
			if WardStory.holds(profile, str(option[0])):
				line = str(option[1])
				break
	elif profile.has_flag("op_sim_failed"):
		line = "The simulator won today. The interns took notes. So did you."
	elif profile.has_flag("chief_triage_under"):
		line = "The crash is cleared. One waited who shouldn't have."
	elif profile.has_flag("chief_rota_gap"):
		line = "The night shift starts with a hole in the rota. Grace is filling it herself."
	else:
		line = "Another day in the chair. The pager went off forty times. You answered every one."
	if is_milestone(day):
		line += " Day %d. Grace brought a cake. She says it isn't for you." % day
	if is_report_day(day):
		match Standing.verdict(profile, board_bar(day)):
			"strong":
				line += " The board calls it a strong quarter."
			"poor":
				line += " The board is worried. So is Mr. Malhotra."
			_:
				line += " The board says 'mixed'. Mrs. Rajan underlined it."
	return line


## The line about a day, shown the evening before.
static func teaser(profile: PlayerProfile, day: int) -> String:
	var report := " And the board report is at five." if is_report_day(day) else ""
	var id := patient_for(day)
	if not id.is_empty():
		return str(CASEBOOK[id]["teaser"]) + report
	if day == ROUNDS_FROM:
		return "Tomorrow: the casebook is closed. The pager isn't. The hard days start now." + report
	var call: Dictionary = CALLS[call_for(profile, day)]
	var what := str(PUZZLE_TEASERS[rounds_puzzle(day)])
	if busy_day(profile, day):
		what = "a rota to fill by eight, and the highway at nine."
	var first := ("Tomorrow is Day %d: " % day if is_milestone(day) else "Tomorrow: ") + what
	if tier_starts(day):
		first = "From tomorrow the hospital is busier: harder cases, tighter rotas, a stricter board. " + first
	return "%s Then %s%s" % [first, str(call.get("teaser", "a hard call.")), report]


## Sets up a Chief's day as it starts: the hospital's standing, the day's
## flags cleared if the day is played again, and what the morning knows.
static func prepare(profile: PlayerProfile, day: int) -> void:
	Standing.start(profile)
	var prefixes := ["op_sim_", "chief_rota_", "chief_triage_", "report_", "board_"]
	var id := patient_for(day)
	if not id.is_empty():
		prefixes.append_array(["op_%s_" % id, "cb_%s_" % id])
	for flag: String in CALL_FLAGS.get(call_for(profile, day), []):
		profile.set_flag(flag, false)
	for flag: String in profile.flags.keys():
		for prefix: String in prefixes:
			if flag.begins_with(prefix):
				profile.set_flag(flag, false)
	profile.set_flag("report_today", is_report_day(day))
	profile.set_flag("cb_yesterday_lost", profile.count("op_lost") > 0)
	profile.set_flag("chief_first_day", day == FIRST_DAY)
	profile.set_flag("chief_rounds", day >= ROUNDS_FROM)
	profile.set_flag("chief_rounds_first", day == ROUNDS_FROM)
	profile.set_flag("grace_away", grace_away(day))
	profile.set_flag("grace_back_today", day == GRACE_BACK)
	profile.set_flag("tier_up_today", tier_starts(day))
	profile.set_flag("milestone_today", is_milestone(day))
	profile.set_flag("busy_today", busy_day(profile, day))
	# Once a day, however often it is replayed: the morning's lost ground,
	# and the count of days in the chair.
	if profile.count("chief_last_day") < day:
		profile.set_count("chief_last_day", day)
		profile.add_count("chief_days", 1)
		if drift(day) > 0:
			Standing.change(profile, {drift_meter(day): -drift(day)})
	# Which of the generated days' small stories plays today.
	for index in 3:
		profile.set_flag("rounds_" + "abc"[index], day >= ROUNDS_FROM and day % 3 == index)
	Standing.sync_flags(profile)


## Just before a beat starts: the board's verdict for the report.
static func before_beat(profile: PlayerProfile, entry: Dictionary) -> void:
	if str(entry.get("id", "")) == "report":
		var verdict := Standing.verdict(profile, board_bar(profile.day))
		for each: String in ["strong", "mixed", "poor"]:
			profile.set_flag("board_" + each, each == verdict)
		profile.set_flag("board_first", profile.count("reports") == 0)
		profile.add_count("reports", 1)
		profile.set_flag("board_warned_before", profile.count("reports_poor") > 0)
		if verdict == "poor":
			profile.add_count("reports_poor", 1)
			profile.set_count("reports_strong_run", 0)
		elif verdict == "strong":
			profile.set_count("reports_poor", 0)
			var run := profile.add_count("reports_strong_run", 1)
			profile.set_count("reports_strong_best", maxi(run, profile.count("reports_strong_best")))
			# A strong report frees money for next quarter.
			Standing.change(profile, {"money": 4})
		else:
			profile.set_count("reports_strong_run", 0)
		profile.set_flag("board_bar_up", board_bar(profile.day) > 0)
		Standing.sync_flags(profile)


## What an operation's outcome does to the town's trust.
static func after_operation(profile: PlayerProfile, outcome: String, sim: bool) -> void:
	if sim:
		Standing.change(profile, {"staff": {"won": 2, "struggled": 0, "failed": -1}[outcome]})
	else:
		Standing.change(profile, {"public": {"won": 3, "struggled": 0, "failed": -4}[outcome]})


## What a puzzle's result does: a rota that holds keeps the nurses, a
## crash sorted right keeps the town's trust.
static func after_task(profile: PlayerProfile, task: TrainingTask) -> void:
	if task is RotaTask:
		var rota := task as RotaTask
		if not rota.uncovered().is_empty():
			Standing.change(profile, {"staff": -4, "public": -2})
		elif rota.all_right():
			Standing.change(profile, {"staff": 3})
		else:
			Standing.change(profile, {"staff": -1})
	elif task is TriageTask:
		var triage := task as TriageTask
		if not triage.under_triaged().is_empty():
			Standing.change(profile, {"public": -4})
		elif triage.all_right():
			Standing.change(profile, {"public": 3})
