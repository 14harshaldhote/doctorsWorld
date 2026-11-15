class_name Reminders
extends RefCounted
## Reminders on the phone, to bring the player back: a page from someone at
## the hospital about what's waiting today (a new patient, a hard week
## starting, the board report), then a nudge to save a winning run, then two
## gentle ones, and then nothing. At most one a day, at the hour the player
## usually plays and never at night, and none at all after a week away.
## Every launch and every save writes a fresh plan that replaces the old
## one, so a player who comes back is never paged about yesterday.
##
## Reminders are off until the player says yes: the game asks after the
## first day (and once more after the first review), and the phone then asks
## for permission. Everything is worked out and scheduled on the device.

## The days after the last session that get a reminder, in order.
const DAYS_AHEAD := [1, 2, 4, 7]
## Reminders come between these hours, local time (never at night).
const EARLIEST_HOUR := 10
const LATEST_HOUR := 20
## Before the game knows when the player plays: early evening.
const USUAL_HOUR := 19
## How many session start hours are remembered.
const KEEP_HOURS := 9
## The game asks after finishing these days, once each, until the player
## says yes.
const ASK_AFTER := [1, 8]
const IDS := {1: "dw_today", 2: "dw_run", 4: "dw_ward", 7: "dw_locker"}

## The page for the day waiting, during the written story: [who, line].
const STORY := {
	1: ["Dr. Iyer", "Your first day, and the lobby's already full. The coffee's mine. The pager's yours."],
	2: ["Dr. Iyer", "The skills lab is open. Everything you break today is plastic. Enjoy that while it lasts."],
	3: ["Dr. Iyer", "Theatre 2 is booked. Rohit is nineteen, and his appendix isn't waiting for his exams."],
	4: ["Sister Grace", "Handover at seven sharp. Six beds, one pager, and bed one wants a word."],
	5: ["Sister Grace", "A boy has swallowed something round and shiny. A coin can wait. A battery can't."],
	6: ["Sister Grace", "You're on call tonight. The lights go down at ten. The doors never lock."],
	7: ["Dr. Iyer", "Dr. Rao does his round today. He'll ask what you saw this week. He already knows."],
	8: ["Dr. Iyer", "Review day. Dr. Rao has read every note you wrote since Monday."],
	9: ["Sister Grace", "Eight months on, and there's a hand wrapped in a tea towel waiting for you."],
	10: ["Dr. Iyer", "Dr. Sethi admitted a 'kidney stone' overnight. Go and press on it yourself."],
	11: ["Dr. Iyer", "Your first keyhole operation. Two ducts look exactly alike. Only one is yours to cut."],
	12: ["Dr. Iyer", "Department meeting this morning. Dr. Sethi is presenting a case. You'll recognise it."],
	13: ["Dr. Iyer", "Review day. Dr. Rao, me, and one empty chair. Yours."],
	14: ["Sister Grace", "Your new intern has been outside the doctors' room since six. She's terrified. So were you."],
	15: ["Sister Grace", "Your intern's drug chart reaches the patient at eight. Read it first."],
	16: ["Sister Grace", "Tonight the whole floor is yours. Dr. Sethi is on call. From home."],
	17: ["Dr. Iyer", "The meeting where doctors say what went wrong is this morning. Mr. Nanda's name is on the slide."],
	18: ["Dr. Iyer", "Review day. Same table. Different chair."],
	19: ["Sister Grace", "Your name is on the theatre door now. Laminated. Your list starts at eight."],
	20: ["Dr. Iyer", "The notes from Mrs. Kurup's last operation are up from the basement. There's a signature on them."],
	21: ["Sister Grace", "News from the top floor. Somebody is leaving, and two people want the office."],
	22: ["Sister Grace", "An ordinary morning on the ward. So far."],
	23: ["Dr. Iyer", "Interview day. The board chair used to be a judge. Don't rehearse."],
	24: ["Sister Grace", "The nurses are voting, the Dean is leaving, and a stranger is measuring your ward."],
	25: ["Sister Grace", "One of the new day cases came back at five this morning. Yellow."],
	26: ["Sister Grace", "The nurses walk out at eight. At seven, you and I decide who nurses whom. Bring coffee."],
	27: ["Dr. Iyer", "The board votes for Chief of Medicine at three. Dr. Kapoor has been practising his pauses."],
	28: ["Sister Grace", "A new intern has been in the corridor since six, reading the fire notices. She's waiting for you."],
}
## The Chief's first week: people you know, on the other side of the bed.
const CASEBOOK := {
	"banerjee": ["Sister Grace", "Mrs. Banerjee is back, with a cut arm and a tin of biscuits. She asked for the Chief by name."],
	"dev": ["Sister Grace", "Mr. Malhotra's son has a pain low on the right. Mr. Malhotra has a list of demands."],
	"tom": ["Sister Grace", "Tom has handed you instruments for years. Today he's on the table."],
	"salim": ["Sister Grace", "A bus, a toll plaza and a row of motorbikes. One of the riders is someone you know."],
	"mehra": ["Sister Grace", "A board member's mother broke her hip at breakfast. Her son is already on the phone."],
	"verghese": ["Sister Grace", "A CarePlus day case is at your door with a belly full of bile. Dr. Kapoor is right behind her."],
	"grace": ["Dr. Iyer", "Sister Grace has been hiding a pain for a month. Today she can't."],
}
## When the weakest of the Chief's three numbers is low.
const LOW_METER := {
	"staff": ["Sister Grace", "The nurses are counting the days until CarePlus rings them back. Come and give them a reason to stay."],
	"money": ["Mr. Malhotra", "I've started switching off the corridor lights. That's how bad the money is."],
	"public": ["Sister Grace", "The town is talking about us again, and not kindly. The reporter is back in the lobby."],
}
## The second day's page when there's no run to save: [first day, last day, who, line].
const NUDGES := [
	[1, 8, "Sister Grace", "Bed four keeps asking whether the new doctor is coming back. I said yes. Don't make me a liar."],
	[1, 13, "Dr. Iyer", "The pager has gone off three times this morning. It isn't my pager."],
	[1, 0, "Sister Grace", "The tea's on and the ward's full. One of those is your problem."],
	[1, 0, "Dr. Iyer", "Your patients don't know you're busy. They only know you're not here."],
	[3, 0, "Tom", "I've laid out your instruments twice. They're getting cold. Instruments don't get cold. Come anyway."],
	[4, 28, "Mr. Malhotra", "Somebody has to sign the bed report. I'd rather it was a doctor."],
	[4, 35, "Mrs. Banerjee", "Beta, you didn't come yesterday. I saved you a biscuit. Then I ate the biscuit."],
	[29, 0, "Mr. Malhotra", "The board meets whether you're here or not. They'd prefer you here."],
	[29, 0, "Sister Grace", "Three people asked for the Chief this morning. I said you were in a meeting. I'm running out of meetings."],
]

## How the plan reaches the phone. Tests use a fake.
static var backend: ReminderBackend = ReminderBackend.new()
## The career the last plan was made for, so the settings screen can make a
## new one when reminders are switched on.
static var profile: PlayerProfile


static func use_backend(next: ReminderBackend) -> void:
	backend = next if next != null else ReminderBackend.new()


static func supported() -> bool:
	return backend.supported()


static func status() -> String:
	return backend.status()


## True when the phone itself has reminders switched off for the game.
static func blocked() -> bool:
	return status() == "denied"


# --- When -------------------------------------------------------------------

## Remembers the local hour a session started, to send reminders when the
## player usually plays.
static func note_play(settings: GameSettings, local_hour: int = -1) -> void:
	var hour := local_hour if local_hour >= 0 else int(Time.get_datetime_dict_from_system()["hour"])
	settings.play_hours.append(clampi(hour, 0, 23))
	while settings.play_hours.size() > KEEP_HOURS:
		settings.play_hours.remove_at(0)


## The hour reminders go out: the middle of the hours the player started
## playing, kept between EARLIEST_HOUR and LATEST_HOUR.
static func usual_hour(hours: Array) -> int:
	if hours.is_empty():
		return USUAL_HOUR
	var sorted := hours.duplicate()
	sorted.sort()
	return clampi(int(sorted[sorted.size() / 2]), EARLIEST_HOUR, LATEST_HOUR)


## The moment (Unix time) of hour o'clock, local time, days_ahead days after
## now. bias_minutes is the time zone's offset from UTC.
static func fire_time(now: int, bias_minutes: int, days_ahead: int, hour: int) -> int:
	var local := now + bias_minutes * 60
	var midnight := local - posmod(local, 86400)
	return midnight + days_ahead * 86400 + hour * 3600 - bias_minutes * 60


# --- What -------------------------------------------------------------------

## The page about the day waiting: [who, line].
static func today_line(career: PlayerProfile) -> Array:
	var day := maxi(1, career.day)
	if STORY.has(day):
		return STORY[day]
	var patient := ChiefDays.patient_for(day)
	if CASEBOOK.has(patient):
		return CASEBOOK[patient]
	if day == ChiefDays.ROUNDS_FROM:
		return ["Sister Grace", "The casebook is closed. The pager isn't. The hard days start now."]
	var walkin := ChiefDays.walkin_for(career, day)
	if not walkin.is_empty():
		return ["Sister Grace", "Today: " + str(ChiefDays.CASEBOOK[walkin]["teaser"])]
	if ChiefDays.event_starts(career, day):
		var event: Dictionary = ChiefDays.EVENTS[ChiefDays.event_for(career, day)]
		return ["Sister Grace", _sentence(str(event["coming"]))]
	if ChiefDays.is_milestone(day):
		return ["Tom", "Day %d. Grace has hidden a cake in the sluice room. It isn't for you, apparently." % day]
	if ChiefDays.tier_starts(day):
		return ["Sister Grace", "The town has grown again. Busier wards, tighter rotas and a stricter board, from today."]
	if ChiefDays.is_report_day(day):
		return ["Mr. Malhotra", "Board report at five. I have the numbers. You have until five."]
	var call: Dictionary = ChiefDays.CALLS.get(ChiefDays.call_for(career, day), {})
	return ["Sister Grace", "Today: " + str(call.get("teaser", "the pager, the ward, and a hard call."))]


## The second page: save the run, mind the weakest number, or a nudge.
static func run_line(career: PlayerProfile) -> Array:
	var run := career.count("op_streak")
	if run >= DayHooks.STREAK_WORTH_SAYING:
		return ["Tom", "Your run is at %d operations won. Theatre's set up. Don't make me put the trays away." % run]
	if career.day >= ChiefDays.FIRST_DAY and Standing.started(career):
		var weakest := Standing.weakest(career)
		if Standing.is_low(career, weakest) and LOW_METER.has(weakest):
			return LOW_METER[weakest]
	var fitting: Array = []
	for nudge: Array in NUDGES:
		if career.day >= int(nudge[0]) and (int(nudge[1]) == 0 or career.day <= int(nudge[1])):
			fitting.append([nudge[2], nudge[3]])
	return fitting[posmod(career.day * 7 + career.count("op_streak_best"), fitting.size())]


static func ward_line(career: PlayerProfile) -> Array:
	if career.day >= ChiefDays.FIRST_DAY:
		return ["Sister Grace", "The board asked where the Chief went. I said a conference. Don't make me a liar."]
	return ["Sister Grace", "The ward's been asking where you went. I said a conference. Don't make me a liar."]


static func locker_line(career: PlayerProfile) -> Array:
	if career.day >= ChiefDays.FIRST_DAY:
		return ["Dr. Iyer", "Your chair's still here. So is the pager. It hasn't stopped."]
	return ["Dr. Iyer", "Your locker's still here. So is your pager. It hasn't stopped."]


## The reminders for a career, soonest first: {id, at, title, body}. Empty
## when reminders are off or there is no career yet.
static func plan(career: PlayerProfile, settings: GameSettings, now: int = -1, bias_minutes: int = 0x7fffffff) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	if career == null or settings == null or not settings.reminders or not career.created:
		return made
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	if bias_minutes == 0x7fffffff:
		bias_minutes = int(Time.get_time_zone_from_system().get("bias", 0))
	var hour := usual_hour(settings.play_hours)
	for days_ahead: int in DAYS_AHEAD:
		var said: Array
		match days_ahead:
			1:
				said = today_line(career)
			2:
				said = run_line(career)
			4:
				said = ward_line(career)
			_:
				said = locker_line(career)
		made.append({"id": IDS[days_ahead], "at": fire_time(now, bias_minutes, days_ahead, hour),
			"title": _clean(str(said[0])), "body": _clean(str(said[1]))})
	return made


## The plan as the phone's side reads it (see addons/dw_reminders).
static func payload(entries: Array, ask: bool = false) -> String:
	var lines := PackedStringArray(["DW1"])
	if ask:
		lines.append("ask")
	for entry: Dictionary in entries:
		lines.append("\t".join(PackedStringArray(["R", _clean(str(entry["id"])), str(int(entry["at"])),
			_clean(str(entry["title"])), _clean(str(entry["body"]))])))
	return "\n".join(lines)


# --- Doing it ---------------------------------------------------------------

## Writes a fresh plan for the career (or clears it when reminders are off).
static func refresh(career: PlayerProfile, settings: GameSettings = null) -> void:
	if career != null:
		profile = career
	if not supported():
		return
	backend.send(payload(plan(profile, settings if settings != null else GameSettings.current)))


## Switches reminders on or off from the settings screen; on asks the phone
## for permission (it only really asks the first time).
static func set_enabled(settings: GameSettings, enabled: bool) -> void:
	settings.reminders = enabled
	if not supported():
		return
	backend.send(payload(plan(profile, settings), enabled))


## True when the game should ask about reminders after finishing a day.
static func should_ask(settings: GameSettings, finished_day: int) -> bool:
	if not supported() or settings.reminders or blocked():
		return false
	return settings.reminders_asked < asks_due(finished_day)


static func asks_due(finished_day: int) -> int:
	var due := 0
	for after: int in ASK_AFTER:
		if finished_day >= after:
			due += 1
	return due


## The player's answer to the in-game question.
static func answer(settings: GameSettings, career: PlayerProfile, finished_day: int, yes: bool) -> void:
	settings.reminders_asked = maxi(settings.reminders_asked, asks_due(finished_day))
	if career != null:
		profile = career
	if yes:
		set_enabled(settings, true)


static func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1) if not text.is_empty() else text


## No tabs or line breaks, which the phone's side uses to split the plan.
static func _clean(text: String) -> String:
	return text.replace("\t", " ").replace("\r", " ").replace("\n", " ").strip_edges()
