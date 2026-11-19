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
## No two weeks run the same. From Day 43 each week is ordinary or brings an
## event: the rains (the highway at its worst), festival week (fireworks
## and crowds) or an outbreak (a bad water main, and nurses off sick). From
## Day 37 a new walk-in patient comes through the door every fourth day,
## and once their operation is done their case joins the simulator.
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
## The hard calls after Day 38, one a day, none twice within CALL_GAP days.
const ROUNDS_CALLS := ["budget_month", "family_complaint", "staff_poach", "inspection", "vip_queue", "drug_shortage",
	"resident_tired", "scanner_down", "blood_bank", "tv_hero", "drug_trial", "night_allowance", "corridor_beds",
	"careplus_offer"]
## A generated call doesn't come round again within this many days.
const CALL_GAP := 6
## The generated days come in weeks from ROUNDS_FROM; week 0 is ordinary.
const WEEK_DAYS := 7
## What each week's event changes:
##   title       the day card's heading that week
##   meter       the meter it costs a point a morning (on top of drift)
##   triage_every  a crash every this many days (0: never; ordinary is 4)
##   busy        extra odds of a busy day, from tier 1
##   cases / talks / afters / pages / teasers   by puzzle kind, in place
##               of the ordinary day's
##   coming      the evening before the week starts ("Tomorrow: ...")
const EVENTS := {
	"monsoon": {"title": "The rains", "meter": "public", "triage_every": 2, "busy": 0.25,
		"talks": {"rota": "monsoon_rota_arrive", "triage": "monsoon_triage_arrive"},
		"pages": {"triage": "Priya: AMBULANCE BAY. The rain's brought the highway in. Now, Chief."},
		"teasers": {"rota": "half the night shift stuck behind floods, and every bed needs a name by eight.",
			"triage": "rain on the highway, and the ambulances already queuing."},
		"coming": "the rains arrive, and the highway turns to glass."},
	"festival": {"title": "Festival week", "meter": "money", "triage_every": 3,
		"cases": {"triage": "festival_triage"}, "afters": {"triage": "festival_triage_after"},
		"talks": {"rota": "festival_rota_arrive", "triage": "festival_triage_arrive"},
		"pages": {"triage": "Priya: AMBULANCE BAY. The festival grounds. Everyone at once, Chief."},
		"teasers": {"rota": "half the nurses on festival leave, and every bed needs a name by eight.",
			"triage": "fireworks, crowds and street food, and all of it ends up in the ambulance bay."},
		"coming": "festival week begins: fireworks, crowds, and half the staff on leave."},
	"outbreak": {"title": "The outbreak", "meter": "staff", "triage_every": 0,
		"cases": {"rota": "outbreak_rota"}, "afters": {"rota": "outbreak_rota_after"},
		"talks": {"rota": "outbreak_rota_arrive", "triage": "outbreak_triage_arrive"},
		"pages": {"rota": "Priya: Desk, Chief. The stomach bug's taken two more nurses, and the beds are filling with it."},
		"teasers": {"rota": "the stomach bug fills the beds and empties the nurses' room.",
			"triage": "the highway doesn't care that there's an outbreak on."},
		"coming": "a water main has burst in the old town, and the stomach bug is at the door."},
}
## A new walk-in patient on Day 37, then every WALKIN_EVERY days until the
## last of them has been seen.
const WALKIN_FROM := 37
const WALKIN_EVERY := 4

## Worked out once per doctor and kept: each day's call and simulator case.
static var _calls := {}
static var _sims := {}

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
	# The walk-ins (walkin: true): a new face every fourth generated day,
	# in an order of the doctor's own. Their day_line follows the week's
	# heading; levels are the hardest their operation goes.
	"arif": {
		"walkin": true, "procedure": "appendix", "patient": "Arif Mirza", "first": "Arif", "pronoun": "he",
		"age": "19", "age_words": "nineteen", "wrong_age": "91", "wrong_age_words": "ninety-one",
		"swaps": [], "team": ["iyer", "tom", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"allergy_known": "cb_arif_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie",
		"row": "A walk-in: the engineering hostel", "page": "Priya: Admissions. A student from the engineering hostel. Pain low on the right, and four friends in the corridor taking notes.",
		"op_row": "Operate: Arif", "op_page": "Dr. Iyer: Theatre 2 at two. His friends have asked if they can watch. They can't.",
		"day_line": "A student from the hostel",
		"end": [["op_arif_failed", "Arif's appendix is out. Dr. Iyer finished it. His friends brought a cake shaped like a kidney. Close enough."],
			["", "Arif's appendix is in a jar. He wants to know if it counts as a practical."]],
		"teaser": "an engineering student whose pain moved from his navel to his right side overnight.",
	},
	"mohan": {
		"walkin": true, "procedure": "hernia", "patient": "Mohan Tiwari", "first": "Mohan", "pronoun": "he",
		"age": "54", "age_words": "fifty-four", "wrong_age": "45", "wrong_age_words": "forty-five",
		"swaps": [["He lays bricks for a living; make it strong.", "He carries gas cylinders up four floors for a living; make it strong."],
			["He'll be back on the scaffolding in six weeks.", "He'll be back on his cylinder round in six weeks."],
			["paratha", "plate of poha"]],
		"team": ["iyer", "tom", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"ate_known": "cb_mohan_history_meal", "allergy_asked": "cb_mohan_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie",
		"row": "A walk-in: the gas cylinder man", "page": "Priya: Admissions. The man who delivers our gas cylinders. He's brought one with him. He says he'll deliver it after.",
		"op_row": "Operate: Mohan", "op_page": "Tom: Theatre 2. Mr. Tiwari has asked us to hurry. He's double-parked.",
		"day_line": "The gas cylinder man",
		"end": [["op_mohan_failed", "Mohan's hernia is mended. Dr. Iyer finished it. His tempo has been towed. He's taking it well."],
			["", "Mohan's hernia is mended. His daughter came from nursing college to check the stitches. She approved."]],
		"teaser": "the man who carries the hospital's gas cylinders, with a lump in his groin that won't go back.",
	},
	"savitri": {
		"walkin": true, "procedure": "wound", "patient": "Savitri Kale", "first": "Mrs. Kale", "pronoun": "she",
		"age": "66", "age_words": "sixty-six", "wrong_age": "56", "wrong_age_words": "fifty-six",
		"swaps": [["She chops onions for a living.", "She pours two hundred cups of tea a day."],
			["She'll be chopping onions in ten days.", "She'll be pouring tea in ten days."],
			["the bowl shattered", "the glass shattered"]],
		"team": ["iyer", "tom", ""], "levels": ["easy", "hard"],
		"op_flags": {"tetanus_known": "cb_savitri_history_tetanus"},
		"arrive": "trolley:sit", "bed": "bed4:sit",
		"row": "A walk-in: the tea stall", "page": "Priya: Admissions. The tea lady from the bus stand, with her hand in a towel. She's brought a flask. For us.",
		"op_row": "Minor theatre: Mrs. Kale's hand", "op_page": "Tom: Minor theatre's laid out. Mrs. Kale's poured us all tea from the flask. It's very good tea.",
		"day_line": "The tea stall at the bus stand",
		"end": [["op_savitri_failed", "Mrs. Kale's hand is closed. Dr. Iyer finished it. She's promised the theatre free tea for a month anyway."],
			["", "Mrs. Kale's hand is stitched. The bus stand has sent a get-well card signed by forty drivers."]],
		"teaser": "the tea lady from the bus stand, with a deep cut and a flask of tea for the nurses.",
	},
	"usha": {
		"walkin": true, "procedure": "gallbladder", "patient": "Usha Krishnan", "first": "Mrs. Krishnan", "pronoun": "she",
		"age": "61", "age_words": "sixty-one", "wrong_age": "16", "wrong_age_words": "sixteen",
		"swaps": [], "team": ["iyer", "neha", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"aspirin_known": "cb_usha_history_medicines", "allergy_asked": "cb_usha_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie",
		"row": "A walk-in: the headmistress", "page": "Priya: Admissions. Mrs. Krishnan. She was my headmistress. I've straightened my uniform twice.",
		"op_row": "Operate: Mrs. Krishnan", "op_page": "Neha: Theatre 2. She was my headmistress too. I've washed my hands three times.",
		"day_line": "The old headmistress",
		"end": [["op_usha_failed", "Mrs. Krishnan's gallbladder is out. Dr. Iyer finished it. She's marked the discharge letter for spelling."],
			["", "Mrs. Krishnan's gallbladder is out. She gave the theatre team 'nine out of ten'. Nobody has ever had ten."]],
		"teaser": "a retired headmistress with a pain under her ribs, and half the nurses were her pupils.",
	},
	"rosy": {
		"walkin": true, "procedure": "hip", "patient": "Rosy Pereira", "first": "Mrs. Pereira", "pronoun": "she",
		"age": "83", "age_words": "eighty-three", "wrong_age": "38", "wrong_age_words": "thirty-eight",
		"swaps": [["her son's wedding in March", "her last pupil's recital in March"], ["eighty-one", "eighty-three"],
			["Warfarin, stopped yesterday, with vitamin K. Her clotting this morning is 1.4.",
				"Warfarin, last dose last night. Vitamin K went in at breakfast. Her clotting's down to 1.4."],
			["You checked her chart yourself. Warfarin, stopped.", "You asked her yourself. Warfarin, last night."],
			["You knew her warfarin had been stopped and told the team.", "You knew about her warfarin and told the team."]],
		"team": ["bhatt", "tom", "khan"], "levels": ["hard", "extreme"],
		"op_flags": {"warfarin_known": "cb_rosy_history_medicines", "allergy_known": "cb_rosy_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie",
		"row": "A walk-in: the piano teacher", "page": "Priya: Admissions. An old lady with a broken hip, asking whether anybody here can feed a cat called Clementine.",
		"op_row": "Operate: Mrs. Pereira's hip", "op_page": "Dr. Bhatt: Theatre 3. The hip is yours. She's asked for music in theatre. Chopin. I've found some.",
		"day_line": "A fall at home",
		"end": [["op_rosy_failed", "Mrs. Pereira's hip is fixed. Dr. Bhatt finished it. Priya is feeding Clementine. Clementine is not grateful."],
			["", "Mrs. Pereira's hip is fixed. She's conducting the ward radio with one finger. Priya is feeding the cat."]],
		"teaser": "a retired piano teacher who fell over her cat, on warfarin, with a hip that won't take her weight.",
	},
	"gurdeep": {
		"walkin": true, "procedure": "spleen", "patient": "Gurdeep Sandhu", "first": "Gurdeep", "pronoun": "he",
		"age": "45", "age_words": "forty-five", "wrong_age": "54", "wrong_age_words": "fifty-four",
		"swaps": [["Dr. Sethi had to take over.", "Dr. Iyer had to take over."],
			["People who fall off scaffolds rarely break one thing.", "People whose lorries roll over rarely break one thing."],
			["where he landed on the scaffold", "where the steering wheel hit him"],
			["he's twenty-four and he'll cough", "he's forty-five and he'll cough"],
			["At two in the morning. Go and tell his wife.", "Go and tell his brother. He drove four hours to get here."],
			["at two in the morning", "in broad daylight"]],
		"team": ["iyer", "tom", "khan"], "levels": ["hard", "extreme"],
		"op_flags": {"allergy_asked": "cb_gurdeep_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie", "music": "emergency",
		"row": "A walk-in: the lorry on the ghat", "page": "Priya: Admissions, now. A lorry driver off the ghat road. He walked in. He shouldn't have been able to.",
		"op_row": "Operate: Gurdeep", "op_page": "Dr. Iyer: Theatre 1, now. His pressure's sliding. Bring your hands.",
		"day_line": "A lorry on the ghat road",
		"end": [["op_gurdeep_failed", "Gurdeep is alive. Dr. Iyer finished it. His brother is asleep in the corridor."],
			["", "Gurdeep is alive, minus a spleen. His brother has brought everyone on the ward a bag of onions."]],
		"teaser": "a lorry rolls on the ghat road, and the driver walks in holding his ribs.",
	},
	"anwar": {
		"walkin": true, "procedure": "hernia", "patient": "Anwar Hussain", "first": "Mr. Hussain", "pronoun": "he",
		"age": "67", "age_words": "sixty-seven", "wrong_age": "76", "wrong_age_words": "seventy-six",
		"swaps": [["He lays bricks for a living; make it strong.", "He's coughed for forty years; make it strong."],
			["He'll be back on the scaffolding in six weeks.", "He'll be back at his sewing machine in six weeks."]],
		"team": ["iyer", "neha", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"ate_known": "cb_anwar_history_meal", "allergy_asked": "cb_anwar_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie",
		"row": "A walk-in: the old tailor", "page": "Priya: Admissions. An old tailor with a lump in his groin and a cough you can hear from the lift.",
		"op_row": "Operate: Mr. Hussain", "op_page": "Neha: Theatre 2. He's asked us to stitch him like a good suit. Small and even.",
		"day_line": "The old tailor",
		"end": [["op_anwar_failed", "Mr. Hussain's hernia is mended. Dr. Iyer finished it. He says the stitches are adequate. From a tailor, that's praise."],
			["", "Mr. Hussain's hernia is mended. He inspected the stitches and said 'good seam'. Neha is framing it."]],
		"teaser": "an old tailor whose cough has finally pushed something out of place.",
	},
	"kavita": {
		"walkin": true, "procedure": "gallbladder", "patient": "Kavita Bhave", "first": "Kavita", "pronoun": "she",
		"age": "44", "age_words": "forty-four", "wrong_age": "64", "wrong_age_words": "sixty-four",
		"swaps": [], "team": ["iyer", "tom", "khan"], "levels": ["easy", "hard", "extreme"],
		"op_flags": {"aspirin_known": "cb_kavita_history_medicines", "allergy_asked": "cb_kavita_history_allergy"},
		"arrive": "trolley:lie", "bed": "bed4:lie",
		"row": "A walk-in: the bus conductor", "page": "Priya: Admissions. A bus conductor, still in uniform, still holding her ticket machine. She came in on her own bus.",
		"op_row": "Operate: Kavita", "op_page": "Tom: Theatre 2. She's asked how long. I said an hour. She said the forty-two does the round trip in fifty minutes.",
		"day_line": "The conductor of the forty-two",
		"end": [["op_kavita_failed", "Kavita's gallbladder is out. Dr. Iyer finished it. Her son has put his phone away. Twice."],
			["", "Kavita's gallbladder is out. Her depot sent a bus to visit. It's parked outside, empty, as a gesture."]],
		"teaser": "a bus conductor rides her own bus in with a pain under her ribs, and two aspirin she shouldn't have taken.",
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
	"vip_queue": {"row": "Somebody important", "go": "desk", "with": "malhotra", "at": 15 * 60,
		"page": "Mr. Malhotra: Chief, the desk, please. Somebody important would like to skip the queue. They always would.",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]],
		"teaser": "somebody important wants to skip the queue."},
	"drug_shortage": {"row": "Not enough to go round", "go": "desk", "with": "priya", "at": 15 * 60,
		"page": "Priya: Pharmacy's run short, Chief. More patients than vials. Somebody has to choose.",
		"put": [["priya", "desk:left"]], "put_end": [["priya", "off"]],
		"teaser": "pharmacy runs short, and somebody has to choose who gets it."},
	"resident_tired": {"row": "Thirty-six hours", "go": "desk", "with": "saxena", "at": 15 * 60 + 30,
		"page": "Dr. Saxena: Chief, it's about the residents' hours. Can I come down? It won't wait.",
		"put": [["saxena", "desk:left"]], "put_end": [["saxena", "off"]],
		"teaser": "Dr. Saxena wants to talk about thirty-six-hour shifts."},
	"scanner_down": {"row": "The scanner's down", "go": "desk", "with": "iyer", "at": 15 * 60,
		"page": "Dr. Iyer: Chief, the scanner. Come and look at my face. That's the scanner's news.",
		"put": [["iyer", "desk:left"]], "put_end": [["iyer", "desk:right"]],
		"teaser": "the scanner dies, and every head injury becomes a guess."},
	"blood_bank": {"row": "The blood bank", "go": "desk", "with": "priya", "at": 16 * 60,
		"page": "Priya: The blood bank's nearly empty, Chief. Desk, please, before the highway notices.",
		"put": [["priya", "desk:left"]], "put_end": [["priya", "off"]],
		"teaser": "the blood bank runs low, and three operations need blood."},
	"tv_hero": {"row": "The cameras want you", "go": "desk", "with": "malhotra", "at": 16 * 60,
		"page": "Mr. Malhotra: Chief! Good news, possibly. The television people want you. Desk?",
		"put": [["malhotra", "desk:left"]], "put_end": [["malhotra", "off"]],
		"teaser": "the television people want a hero doctor. Guess who."},
	"drug_trial": {"row": "A drug trial", "go": "desk", "with": "iyer", "at": 15 * 60 + 30,
		"page": "Dr. Iyer: Chief, there's a man from a drug company at the desk. He's brought a pen with his logo on it. For you.",
		"put": [["iyer", "desk:left"]], "put_end": [["iyer", "desk:right"]],
		"teaser": "a drug company wants your patients for a trial."},
	"night_allowance": {"row": "The nurses' committee", "go": "desk", "with": "priya", "at": 16 * 60 + 30,
		"page": "Priya: The nurses' committee would like five minutes, Chief. They've brought a spreadsheet.",
		"put": [["priya", "desk:left"]], "put_end": [["priya", "off"]],
		"teaser": "the nurses' committee wants a number for nights."},
	"corridor_beds": {"row": "No beds", "go": "desk", "with": "priya", "at": 15 * 60 + 30,
		"page": "Priya: Chief, we've run out of beds. Again. Come and see the corridor.",
		"put": [["priya", "desk:left"]], "put_end": [["priya", "off"]],
		"teaser": "the beds run out. Again."},
	"careplus_offer": {"row": "Dr. Kapoor's proposal", "go": "desk", "with": "kapoor", "at": 16 * 60,
		"page": "Priya: Dr. Kapoor is at the desk with a proposal. And a smile. Mostly the smile.",
		"put": [["kapoor", "desk:left"]], "put_end": [["kapoor", "off"]],
		"teaser": "Dr. Kapoor comes with a proposal, and a smile."},
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
	"vip_queue": ["hc_vip_queue_queue", "hc_vip_queue_squeeze", "hc_vip_queue_private"],
	"drug_shortage": ["hc_drug_shortage_sickest", "hc_drug_shortage_borrow", "hc_drug_shortage_buy"],
	"resident_tired": ["hc_resident_tired_cap", "hc_resident_tired_rest", "hc_resident_tired_tough"],
	"scanner_down": ["hc_scanner_down_divert", "hc_scanner_down_pay", "hc_scanner_down_careful"],
	"blood_bank": ["hc_blood_bank_appeal", "hc_blood_bank_postpone", "hc_blood_bank_buy"],
	"tv_hero": ["hc_tv_hero_team", "hc_tv_hero_me", "hc_tv_hero_no"],
	"drug_trial": ["hc_drug_trial_properly", "hc_drug_trial_fast", "hc_drug_trial_decline"],
	"night_allowance": ["hc_night_allowance_pay", "hc_night_allowance_half", "hc_night_allowance_no"],
	"corridor_beds": ["hc_corridor_beds_seminar", "hc_corridor_beds_discharge", "hc_corridor_beds_divert"],
	"careplus_offer": ["hc_careplus_offer_terms", "hc_careplus_offer_no", "hc_careplus_offer_sell"],
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
## The day's last line in an event's week, when nothing else went wrong.
const EVENT_DAY_ENDS := {
	"monsoon": "The rain hasn't stopped all day. Neither have you. The basement is a paddling pool.",
	"festival": "Fireworks outside until midnight. Burns inside until two. Somebody left sweets at the desk.",
	"outbreak": "The water's still bad in the old town. Every bed near the sluice is full, and nobody's complaining about the smell any more.",
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
## generated ones, none that came up in the CALL_GAP days before.
static func call_for(profile: PlayerProfile, day: int) -> String:
	if CALL_DAYS.has(day):
		return str(CALL_DAYS[day])
	if day < FIRST_DAY:
		return ""
	var first := _last_written_call() + 1
	var made: Array = _calls.get(profile.name, [])
	while first + made.size() <= day:
		var recent := made.slice(maxi(made.size() - CALL_GAP, 0))
		var options: Array = ROUNDS_CALLS.filter(func(id: String) -> bool: return not id in recent)
		made.append(str(SeededRandom.new(_seed(profile, first + made.size(), "call")).pick(options)))
	_calls[profile.name] = made
	return str(made[day - first])


static func _last_written_call() -> int:
	var last := 0
	for day: int in CALL_DAYS:
		last = maxi(last, day)
	return last


## The puzzle on a generated day: a staffing rota most days, a major
## incident every fourth (more often in the rains and festival week, never
## in an outbreak, when every day is the outbreak's rota).
static func rounds_puzzle(profile: PlayerProfile, day: int) -> String:
	var every := int((EVENTS.get(event_for(profile, day), {}) as Dictionary).get("triage_every", 4))
	if every <= 0:
		return "rota"
	return "triage" if (day - ROUNDS_FROM) % every == every - 1 else "rota"


## The week of the generated days a day falls in (Days 36 to 42 are week 0).
static func week(day: int) -> int:
	return -1 if day < ROUNDS_FROM else (day - ROUNDS_FROM) / WEEK_DAYS


## This week's event, or "" for an ordinary week. Weeks come in fours: the
## first four bring all three events and one ordinary week, and after that
## each four is a seeded shuffle of the same, never the same twice running.
static func event_for(profile: PlayerProfile, day: int) -> String:
	var number := week(day)
	if number < 1:
		return ""
	var block := (number - 1) / 4
	var order := _event_block(profile, block)
	if block > 0 and order[0] == _event_block(profile, block - 1)[3]:
		order = [order[1], order[0], order[2], order[3]]
	return str(order[(number - 1) % 4])


static func _event_block(profile: PlayerProfile, block: int) -> Array:
	var dice := SeededRandom.new(_seed(profile, block, "events"))
	if block == 0:
		return dice.shuffled(EVENTS.keys()) + [""]
	return dice.shuffled(EVENTS.keys() + [""])


## True on the first day of an event's week.
static func event_starts(profile: PlayerProfile, day: int) -> bool:
	return not event_for(profile, day).is_empty() and (day - ROUNDS_FROM) % WEEK_DAYS == 0


## The walk-in patients, in the order this doctor meets them.
static func walkins(profile: PlayerProfile) -> Array:
	var ids: Array = CASEBOOK.keys().filter(func(id: String) -> bool: return bool(CASEBOOK[id].get("walkin", false)))
	ids.sort()
	return SeededRandom.new(_seed(profile, 0, "walkins")).shuffled(ids)


## The walk-in patient on a day, or "".
static func walkin_for(profile: PlayerProfile, day: int) -> String:
	if day < WALKIN_FROM or (day - WALKIN_FROM) % WALKIN_EVERY != 0:
		return ""
	var order := walkins(profile)
	var index := (day - WALKIN_FROM) / WALKIN_EVERY
	return str(order[index]) if index < order.size() else ""


## The day a walk-in patient comes in.
static func walkin_day(profile: PlayerProfile, id: String) -> int:
	return WALKIN_FROM + WALKIN_EVERY * walkins(profile).find(id)


## Whoever is on the table today: the casebook's patient or a walk-in.
static func patient_today(profile: PlayerProfile, day: int) -> String:
	var id := patient_for(day)
	return id if not id.is_empty() else walkin_for(profile, day)


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
	if level <= 0 or not patient_today(profile, day).is_empty():
		return false
	var extra := float((EVENTS.get(event_for(profile, day), {}) as Dictionary).get("busy", 0.0))
	var odds := minf(0.2 + 0.15 * float(level - 1) + extra, 0.85)
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


## The casebook case loaded into the simulator on a generated day, never
## yesterday's. Walk-in patients join once their own day has passed.
static func sim_for(profile: PlayerProfile, day: int) -> String:
	if day < ROUNDS_FROM:
		return ""
	var ids: Array = CASEBOOK.keys()
	ids.sort()
	var seen := {}
	for id: String in walkins(profile):
		seen[id] = walkin_day(profile, id)
	var made: Array = _sims.get(profile.name, [])
	while ROUNDS_FROM + made.size() <= day:
		var on := ROUNDS_FROM + made.size()
		var yesterday := str(made[made.size() - 1]) if not made.is_empty() else ""
		var options := ids.filter(func(id: String) -> bool: return id != yesterday and int(seen.get(id, 0)) < on)
		made.append(str(SeededRandom.new(_seed(profile, on, "sim")).pick(options)))
	_sims[profile.name] = made
	return str(made[day - ROUNDS_FROM])


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
		found.append({"id": "morning", "talk": "cb_%s_morning" % id, "with": partner(day)})
		_patient_beats(profile, day, id, (CASEBOOK[id] as Dictionary).get("puzzle", []), found)
	else:
		found.append({"id": "morning", "talk": "rounds_morning", "with": "iyer"})
		var walkin := walkin_for(profile, day)
		if not walkin.is_empty():
			_patient_beats(profile, day, walkin, rounds_puzzle_entry(profile, day, rounds_puzzle(profile, day)), found)
		else:
			var kinds := ["rota", "triage"] if busy_day(profile, day) else [rounds_puzzle(profile, day)]
			for kind: String in kinds:
				var beat := _puzzle_beat(rounds_puzzle_entry(profile, day, kind))
				beat["levels"] = puzzle_levels(day)
				found.append(beat)
			found.append(_sim_beat(profile, day))
			found.append(_call_beat(call_for(profile, day), day))
	# Every third day something goes wrong, before the day's last beat.
	var crisis := Crises.beat(profile, day)
	if not crisis.is_empty():
		found.insert(maxi(1, found.size() - 1), crisis)
	if is_report_day(day):
		found.append({"id": "report", "row": "The board's report", "where": "seminar", "at": 17 * 60,
			"card": ["Seminar room · 17:00", "Mrs. Rajan has your numbers. So does Mr. Malhotra. So, somehow, does the newspaper."],
			"talk": "board_report", "with": "rajan", "slide": "BOARD REPORT\nChief of Medicine",
			"put": [["rajan", "seminar:head"], ["malhotra", "seminar:seat1"], ["iyer", "seminar:seat2"], ["you", "seminar:seat5"]]})
	return found


## A generated day's puzzle of a kind: [task, case, arrive talk, after talk,
## at], with this week's event's case and talks in place of the ordinary.
static func rounds_puzzle_entry(profile: PlayerProfile, day: int, kind: String) -> Array:
	var puzzle: Array = (ROUNDS_PUZZLES[kind] as Array).duplicate()
	var event: Dictionary = EVENTS.get(event_for(profile, day), {})
	puzzle[1] = str((event.get("cases", {}) as Dictionary).get(kind, puzzle[1]))
	puzzle[2] = str((event.get("talks", {}) as Dictionary).get(kind, puzzle[2]))
	puzzle[3] = str((event.get("afters", {}) as Dictionary).get(kind, puzzle[3]))
	puzzle.append(9 * 60 + 5 if kind == "triage" else 8 * 60)
	if (event.get("pages", {}) as Dictionary).has(kind):
		puzzle.append(str(event["pages"][kind]))
	return puzzle


## A patient's day: admitted and asked, the operation, the hard call and
## the day's puzzle (a crash comes first, a rota last). Walk-ins take the
## generated day's puzzle and difficulties.
static func _patient_beats(profile: PlayerProfile, day: int, id: String, puzzle: Array, found: Array[Dictionary]) -> void:
	var entry: Dictionary = CASEBOOK[id]
	var walkin := bool(entry.get("walkin", false))
	var triage_first := not puzzle.is_empty() and str(puzzle[0]) == "triage"
	if triage_first:
		found.append(_puzzle_beat(puzzle))
	var call := _call_beat(call_for(profile, day), day)
	var admit := {"id": "patient", "row": str(entry["row"]), "go": "trolley", "talk": "cb_%s_arrive" % id, "with": id,
		"page": str(entry["page"]), "at": 11 * 60 if triage_first else 9 * 60 + 30,
		"put": [[id, str(entry["arrive"])], ["priya", "trolley:other"]] + (entry.get("put", []) as Array),
		"tasks": [["history", "cb_%s_history" % id]], "after": "cb_%s_after" % id,
		"put_end": [[id, str(entry["bed"])], ["priya", "off"]] + _offs(entry.get("put", []))}
	if entry.has("music"):
		admit["music"] = entry["music"]
	found.append(admit)
	if bool(entry.get("call_first", false)):
		found.append(call)
	var op := _op_beat(profile, id, entry)
	if walkin:
		var allowed: Array = entry["levels"]
		var levels: Array = puzzle_levels(day).filter(func(level: String) -> bool: return level in allowed)
		op["levels"] = levels if not levels.is_empty() else [allowed[allowed.size() - 1]]
	found.append(op)
	if not bool(entry.get("call_first", false)):
		found.append(call)
	if not puzzle.is_empty() and not triage_first:
		found.append(_puzzle_beat(puzzle))
	if walkin:
		for beat: Dictionary in found:
			if str(beat["id"]) in ["rota", "triage"]:
				beat["levels"] = puzzle_levels(day)


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
	# An event's own page ([5]).
	if puzzle.size() > 5:
		beat["page"] = str(puzzle[5])
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
			"wrong_note": "The board had %s as %s. %s's %s. A wrong age on a board means somebody opened the wrong file." % [
				entry["first"], entry["wrong_age"], str(entry["pronoun"]).capitalize(), entry["age"]],
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
	var event := event_for(profile, day)
	var head := str(EVENTS[event]["title"]) if not event.is_empty() else "Chief of Medicine"
	if is_milestone(day):
		return "Day %d · A milestone" % day
	var walkin := walkin_for(profile, day)
	if not walkin.is_empty():
		return "%s · %s" % [head, CASEBOOK[walkin]["day_line"]]
	if is_report_day(day):
		return "%s · Board report at five" % head
	if busy_day(profile, day):
		return "%s · A rota and a crash" % head
	if rounds_puzzle(profile, day) == "triage":
		return "%s · Major incident" % head
	return "%s · Day %d in the chair" % [head, day - DayHooks.LAST_STORY_DAY]


## The day's last line.
static func end_line(profile: PlayerProfile, day: int) -> String:
	var id := patient_today(profile, day)
	var event := event_for(profile, day)
	var line := ""
	if not id.is_empty():
		for option: Array in CASEBOOK[id]["end"]:
			if WardStory.holds(profile, str(option[0])):
				line = str(option[1])
				break
	elif profile.has_flag("op_sim_failed"):
		line = "The simulator won today. The interns took notes. So did you."
	elif profile.has_flag("festival_triage_under"):
		line = "The festival grounds are cleared. One waited who shouldn't have."
	elif profile.has_flag("chief_triage_under"):
		line = "The crash is cleared. One waited who shouldn't have."
	elif profile.has_flag("outbreak_rota_gap"):
		line = "The outbreak ward starts the night with a bed nobody's watching. Priya is taking it herself."
	elif profile.has_flag("chief_rota_gap"):
		line = "The night shift starts with a hole in the rota. Grace is filling it herself."
	else:
		line = str(EVENT_DAY_ENDS.get(event, "Another day in the chair. The pager went off forty times. You answered every one."))
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
	var event: Dictionary = EVENTS.get(event_for(profile, day), {})
	var kind := rounds_puzzle(profile, day)
	var what := str((event.get("teasers", {}) as Dictionary).get(kind, PUZZLE_TEASERS[kind]))
	if busy_day(profile, day):
		what = "a rota to fill by eight, and the highway at nine."
	var walkin := walkin_for(profile, day)
	if not walkin.is_empty():
		what = str(CASEBOOK[walkin]["teaser"])
	var opener := "Tomorrow is Day %d: " % day if is_milestone(day) else "Tomorrow: "
	var first := opener + what
	if event_starts(profile, day):
		first = "%s%s First, %s" % [opener, event["coming"], what]
	if tier_starts(day):
		first = "From tomorrow the hospital is busier: harder cases, tighter rotas, a stricter board. " + first
	return "%s Then %s%s" % [first, str(call.get("teaser", "a hard call.")), report]


## Sets up a Chief's day as it starts: the hospital's standing, the day's
## flags cleared if the day is played again, and what the morning knows.
static func prepare(profile: PlayerProfile, day: int) -> void:
	Standing.start(profile)
	var prefixes := ["op_sim_", "chief_rota_", "chief_triage_", "festival_triage_", "outbreak_rota_", "report_", "board_"]
	var id := patient_today(profile, day)
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
	profile.set_flag("walkin_today", not walkin_for(profile, day).is_empty())
	var event := event_for(profile, day)
	for each: String in EVENTS:
		profile.set_flag("event_" + each, each == event)
	profile.set_flag("event_starts", event_starts(profile, day))
	# Once a day, however often it is replayed: the morning's lost ground,
	# and the count of days in the chair.
	if profile.count("chief_last_day") < day:
		profile.set_count("chief_last_day", day)
		profile.add_count("chief_days", 1)
		if drift(day) > 0:
			Standing.change(profile, {drift_meter(day): -drift(day)})
		# An event's week costs a point a morning from its own meter.
		if not event.is_empty():
			Standing.change(profile, {str(EVENTS[event]["meter"]): -1})
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
	if task is CrisisTask:
		# The town hears how a crisis went: well handled, or on WhatsApp.
		Standing.change(profile, {"public": 2, "staff": 1} if (task as CrisisTask).all_right() else {"public": -2})
	elif task is RotaTask:
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
