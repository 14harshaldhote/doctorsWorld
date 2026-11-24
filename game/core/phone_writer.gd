class_name PhoneWriter
extends RefCounted
## The phone messages the game writes itself, from what really happened,
## so the phone never runs dry, not even a hundred days into a Chief's
## career: Varun's reel every day of the race, an evening message from home
## on days the story leaves quiet (gentler after a patient is lost), the
## batch group arguing about the race, the hospital's page and the local
## paper on a Chief's days, and a thank-you from someone casualty sent home
## well (with their real name, kept by PhoneBook.note_day).
##
## Each pick is seeded by the day and the doctor's name, so two careers
## read differently but one career always reads the same, and nothing is
## stored that can be worked out again. Words only: no drugs, doses or
## diagnoses beyond a family's own plain words.

## Varun's reel captions, one for each of his days in Rival.DAYS (same
## order), and the picture that goes with it.
const REELS := [
	["Golden hour. Golden hands. Keyhole gallbladder number 47. #ScrubbedIn #SunsetSurgeon", "sunset"],
	["My consultant called me 'promising' in front of the whole department. Framed the minutes. Humbled. Mostly framed.", "certificate"],
	["Power nap in the quietest room at CarePlus. Don't ask which room. #Rest", "scanner"],
	["Gave a talk on Leadership in Surgery today. Lots of questions. Mostly 'who are you'. #ThoughtLeader", "stage"],
	["Some patients aren't ready for excellence. And that's okay. #Growth", "sunset"],
	["Episode 3 of Scrubbed In, No Cap is LIVE. Eleven listeners and counting. Mummy, stop sharing it in the family group.", "podcast"],
	["Soft reset at the CarePlus wellness retreat. Surgeons need stillness too. #Recharge", "retreat"],
	["Caught a missed fracture on nights. Not to brag. Okay, to brag a little.", "xray"],
	["Respect your scrub nurses. That's today's lesson. No further questions. #Humbled", "theatre"],
	["Twelve feet tall at the highway signal. If you see me, honk. Not too much. #CarePlusFamily", "hoarding"],
	["Long day. Very long day. Not discussing it. #SurgeonLife", "theatre"],
	["Shoutout to my 'friend' at Riverside. Healthy competition is healthy. #NoHardFeelings #SomeHardFeelings", "gym"],
	["Two cases back to back. Called Mummy in between. Both went well. The cases. And Mummy.", "theatre"],
	["Turning off comments for my mental health. #Boundaries", "sunset"],
	["Surgeons don't sit. Lunch, standing. #Grindset #NoDaysOff", "food"],
	["Proud of my team for my consultant's case today. #Teamwork", "theatre"],
]

## Evenings from home: [who, text, photo or ""].
const HOME := [
	["mum", "Did you eat dinner, or just 'something'? 'Something' is not a meal.", ""],
	["dad", "", "goodmorning"],
	["anu", "ok so hypothetically if i bunk chem practical would a note from my own sibling count. asking for a friend. the friend is me", ""],
	["mum", "Your father fixed the geyser. Now it's hot only when it feels like it. Like him.", ""],
	["dad", "Is it true raw garlic cures BP? Sharma uncle says. Sharma uncle has BP.", ""],
	["anu", "mum is making me eat 'brain food' for exams. its walnuts. i'm in my walnut era. send help", ""],
	["mum", "Mrs. Kulkarni from the third floor asked if you can look at her knee. I said yes. You're welcome.", ""],
	["dad", "Doctor joke: why did the cookie go to the doctor? It was feeling crummy. Your mother didn't laugh. You may.", ""],
	["anu", "ur room has my stuff now. ur posters r gone. ur welcome for the glow up", ""],
	["mum", "I saw a show where doctors kiss in the lift. Do you do that? Don't do that.", ""],
	["dad", "My phone says 'storage full'. Is that serious. Should I come to the hospital.", ""],
	["anu", "do doctors get free strepsils. asking for my voice. i'm class rep now, its a whole thing", ""],
	["mum", "Sleep before twelve tonight. I'll know if you don't. I always know.", ""],
	["dad", "Watched a doctor show. They said 'stat' twenty times. Do you say stat? Say stat once for me.", ""],
	["anu", "papa forwarded a 'miracle cure' video to the family group again. pls say something. he only listens to u", ""],
	["mum", "Made your favourite today, then remembered you're not here. Your father ate it. Twice.", "tiffin"],
	["dad", "Your mother says I should reduce salt. I have reduced listening.", ""],
	["anu", "lowkey miss u. highkey want my charger back", ""],
	["mum", "Your old school teacher asked about you. I said you save lives. She said 'that one?' I said yes, that one.", ""],
	["dad", "Read on WhatsApp that doctors hate this one simple trick. What is the trick? Asking for your mother.", ""],
	["anu", "told my friends ur a doctor. they think ur so cool. i told them u cry at dog videos. balance", ""],
	["mum", "Drink water. Not coffee. Coffee is not water. Water is water.", ""],
	["dad", "Proud of you. That's all. Your mother is making me add 'eat properly'. Eat properly.", ""],
	["anu", "mum asked me to ask u if u r eating. r u eating. ok i asked. bye", ""],
	["mum", "It's raining here. Take an umbrella. If it's not raining there, take it anyway.", "rain"],
	["dad", "The neighbour asked if you treat cats. I said she treats everything. Was that right?", ""],
	["anu", "the dog next door barks at 6am every day. can u prescribe it something. for me. to sleep through it", ""],
	["mum", "Your cousin got a job in Bangalore. In IT. Very good. Very sitting-down job. Unlike some people.", ""],
]
## After a patient was lost: gentler, and nobody asks.
const HOME_GENTLE := [
	["mum", "You sound quiet today. You don't have to tell me. Eat something and sleep. I'm here."],
	["mum", "Bad day? You don't have to explain. Come home Sunday. I'll make rajma and not ask anything."],
	["dad", "Your mother says you had a hard day. Even the best doctors have those. I read it somewhere. It's true this once."],
	["mum", "I lit a lamp today. For you, and for your patient. I don't know the name. God does."],
	["anu", "mum says u had a bad day. i'm not good at this. here is a picture of a dog. ok i don't have one. imagine a dog"],
]

## The batch group on the race. %d is how far ahead, in XP.
const BATCH_AHEAD := [
	["varun", "Not that anyone's counting, but Riverside is %d XP ahead this month? Must be the paper charts. Very retro. Very hardworking."],
	["varun", "Can someone explain how XP works at Riverside. Asking for nobody. Definitely not because I'm %d behind."],
	["sana", "Breaking news from Ohio: Varun is %d XP behind and has gone quiet. First time since 2020."],
]
const BATCH_BEHIND := [
	["varun", "Just checked. I'm %d XP ahead this month. Not that I check. CarePlus has a leaderboard. I'm on it. Top."],
	["varun", "%d XP ahead. I'd say good game but it isn't a game. It's a lifestyle."],
	["rocky", "varun is %d ahead and has changed his dp to a lion. we are all suffering"],
]
const BATCH_IDLE := [
	["sana", "It's 4 am in Ohio. I'm awake. My cat is awake. We're both judging this chat."],
	["rocky", "studied 14 hours today. remembered 3 things. one of them is my own name"],
	["neel", "reminder that sunscreen is self care. even on nights. ESPECIALLY on nights"],
	["neel", "patient asked if i'm old enough to be a doctor. i said i moisturise"],
	["rocky", "pg entrance coming. if anyone needs me i'm in the library. i live here now. the guard knows my name"],
	["sana", "Got an interview call! Minnesota. It's minus thirty there. I'll finally be cold enough to sleep."],
	["varun", "CarePlus canteen has a sushi counter now. Anyway, how's Riverside's poha."],
	["neel", "my senior just called a pimple 'a lesion of concern'. i have never felt more seen"],
]

## The hospital's own page on a Chief's days.
const HOSPITAL_POSTS := [
	["Hand hygiene week! Wash your hands. Then wash them again. Then once more, because we said so.", "hospital"],
	["Good news: the lift on the left is working again! (It is not.)", "hospital"],
	["Visiting hours are 4 to 7. Not 4 am. Bed six's family, we see you.", "ward"],
	["Our canteen now serves millet dosa. Nobody asked. Here it is.", "food"],
	["Blood donation camp this Saturday. Free biscuits. Real biscuits, not chakli.", "cake"],
	["Please do not bring pressure cookers into the wards. You know who you are.", "tiffin"],
	["Riverside's nurses: the reason anything works here. Thank you.", "group"],
	["Reminder: the parking lot is for cars. Not wedding photos. Not again.", "hospital"],
]
## The local paper on a Chief's days.
const NEWS_POSTS := [
	"Riverside City Hospital's casualty sees record numbers this week. Staff say 'please stop eating street prawns'.",
	"CarePlus Hospitals opens a 'luxury maternity suite' with a chandelier. Riverside opens a second tap in the waiting room.",
	"Monsoon brings dengue cases up across the city. Doctors ask residents to empty their coolers and flower pots.",
	"Local man swallows his own house key, walks to Riverside himself. 'I didn't want to bother anyone,' he says.",
	"Riverside City Hospital named 'most improved' in the state's hospital survey. The lift was not inspected.",
]

const THANKS_HOME := [
	"Doctor, this is {sender}, {called}'s {relation}. {He} is home and eating like nothing happened. The nurse gave me your number. Sorry. Thank you.",
	"Hello Doctor, {called}'s {relation} here. {He} keeps telling everyone the young doctor 'didn't panic'. We didn't know doctors could panic. Thank you.",
	"Doctor ji, namaste. {called}'s {relation}. {what} is better. {He} wanted to message you {himself}, but {he} types with one finger. So I am typing. Thank you.",
]
const THANKS_WARD := [
	"Doctor, this is {sender}, {called}'s {relation}. {He} is sitting up and complaining about the food. The nurses say that's a good sign. Thank you for last night.",
	"Hello Doctor, {called}'s {relation}. They say you moved fast. {He} says you were 'very calm for someone so young'. We say thank you.",
]
const THANKS_SELF := [
	"Hello Doctor. {sender} here, from casualty. {what}. Much better now. Your hospital tea is terrible. Thank you for everything else.",
	"Doctor, it's {sender}. You probably don't remember me. Casualty, {what_low}. I remember you. Thank you.",
]


static func _roll(profile: PlayerProfile, what: String, day: int) -> int:
	return absi(("%s|%s|%d" % [what, profile.name, day]).hash())


## Every message the game writes for the last few days, as PhoneBook items.
static func items(profile: PlayerProfile) -> Array:
	var found: Array = []
	var first := maxi(1, profile.day - PhoneBook.WINDOW + 1)
	var home_days := _written_days(profile, ["family", "mum", "dad", "anu"])
	var batch_days := _written_days(profile, ["batch"])
	for day in range(first, profile.day + 1):
		if day >= Rival.FIRST_DAY:
			found.append(reel(profile, day))
		if day >= 2 and not home_days.has(day):
			found.append(home(profile, day))
		if day >= Rival.FIRST_DAY and day % 3 == 0 and not batch_days.has(day):
			found.append(batch(profile, day))
		if day > DayHooks.LAST_STORY_DAY and day % 4 == 1:
			found.append(hospital_post(profile, day))
		if day > DayHooks.LAST_STORY_DAY and day % 9 == 4:
			found.append(news_post(profile, day))
		if Outbreak.starts_on(profile.count("hospital_seed"), day):
			found.append(outbreak_post(profile, day))
	# How the colleagues' asks went (stage 26), and Mum asking for a call
	# (stage 27).
	found.append_array(Lives.items(profile))
	found.append_array(Life.items(profile))
	return found


## The days the story already has a message on, in these chats.
static func _written_days(profile: PlayerProfile, chats: Array) -> Dictionary:
	var days := {}
	for entry: Dictionary in PhoneBook.data().get("chats", []):
		if entry.has("answer_to") or str(entry.get("chat", "")) not in chats:
			continue
		if PhoneBook.holds(profile, str(entry.get("when", ""))):
			days[int(entry.get("day", 0))] = true
	return days


static func _make(id: String, kind: String, chat: String, from: String, text: String, photo: String, day: int,
		at: int) -> Dictionary:
	return {"id": id, "kind": kind, "chat": chat, "from": from, "text": text, "photo": photo, "caption": "",
		"deleted": false, "reply": [], "day": day, "at": at, "stamp": PhoneBook.stamp(day, at)}


## Varun's reel for a day of the race.
static func reel(profile: PlayerProfile, day: int) -> Dictionary:
	var index := absi(("varun_%d" % day).hash()) % Rival.DAYS.size()
	var entry: Array = REELS[index % REELS.size()]
	var roll := _roll(profile, "reel", day)
	var post := _make("gen_reel_%d" % day, "feed", "", "varun", str(entry[0]), str(entry[1]), day, 13 * 60 + roll % 300)
	post["likes"] = 600 + roll % 4200
	return post


## The evening message from home.
static func home(profile: PlayerProfile, day: int) -> Dictionary:
	var note: Dictionary = PhoneBook.state(profile)["days"].get(str(day), {})
	var roll := _roll(profile, "home", day)
	var at := 20 * 60 + 30 + roll % 100
	if bool(note.get("lost", false)):
		var gentle: Array = HOME_GENTLE[roll % HOME_GENTLE.size()]
		return _make("gen_home_%d" % day, "chat", "family", str(gentle[0]), str(gentle[1]), "", day, at)
	# Walks the list a different way for each career, never twice in a row.
	var step := 7 if HOME.size() % 7 != 0 else 5
	var entry: Array = HOME[(roll % HOME.size() + day * step) % HOME.size()]
	var message := _make("gen_home_%d" % day, "chat", "family", str(entry[0]), str(entry[1]), str(entry[2]), day, at)
	if str(entry[2]) == "goodmorning":
		message["caption"] = "Good Morning. Drink eight glasses of water. Forwarded as received."
	elif str(entry[2]) == "tiffin":
		message["caption"] = "Your share. In spirit."
	elif str(entry[2]) == "rain":
		message["caption"] = "From the balcony. Your umbrella is still here."
	return message


## The batch group, on a race day: how the month stands (as it stood when
## that day ended), or just the group being the group.
static func batch(profile: PlayerProfile, day: int) -> Dictionary:
	var note: Dictionary = PhoneBook.state(profile)["days"].get(str(day), {})
	var roll := _roll(profile, "batch", day)
	var at := 23 * 60 + roll % 50
	var lead := int(note.get("lead", 0))
	var entry: Array
	var text := ""
	if note.has("lead") and absi(lead) >= Rival.TIE:
		entry = (BATCH_AHEAD if lead > 0 else BATCH_BEHIND)[roll % BATCH_AHEAD.size()]
		text = str(entry[1]) % absi(lead)
	else:
		entry = BATCH_IDLE[(roll + day) % BATCH_IDLE.size()]
		text = str(entry[1])
	return _make("gen_batch_%d" % day, "chat", "batch", str(entry[0]), text, "", day, at)


static func hospital_post(profile: PlayerProfile, day: int) -> Dictionary:
	var roll := _roll(profile, "page", day)
	var entry: Array = HOSPITAL_POSTS[(day / 4 + roll) % HOSPITAL_POSTS.size()]
	var post := _make("gen_page_%d" % day, "feed", "", "hospital", str(entry[0]), str(entry[1]), day, 10 * 60 + roll % 120)
	post["likes"] = 20 + roll % 300
	return post


static func news_post(profile: PlayerProfile, day: int) -> Dictionary:
	var roll := _roll(profile, "news", day)
	var post := _make("gen_news_%d" % day, "feed", "", "news", str(NEWS_POSTS[(day / 9 + roll) % NEWS_POSTS.size()]), "news",
		day, 8 * 60 + roll % 90)
	post["likes"] = 300 + roll % 3000
	return post


## The district health office's notice on the morning an invented fever
## starts going round (Outbreak), saying it's made up.
static func outbreak_post(profile: PlayerProfile, day: int) -> Dictionary:
	var roll := _roll(profile, "outbreak", day)
	var text := Outbreak.news(profile.count("hospital_seed"), day)
	var post := _make("gen_outbreak_%d" % day, "feed", "", "news", text, "news", day, 7 * 60 + 30 + roll % 60)
	post["likes"] = 500 + roll % 2500
	return post


## A thank-you from someone casualty treated well today (a kept item for
## PhoneBook, arriving tonight), or {} (nobody, or not today).
static func thanks(profile: PlayerProfile, day: int, sim: ShiftSim) -> Dictionary:
	if sim == null:
		return {}
	var well: Array = []
	for patient: ShiftPatient in sim.patients:
		if patient.decided() and patient.outcome == "better" and not str(patient.condition.get("plain", "")).is_empty():
			well.append(patient)
	if well.is_empty():
		return {}
	var rng := SeededRandom.new(_roll(profile, "thanks", day))
	if not rng.chance(0.6):
		return {}
	var patient: ShiftPatient = rng.pick(well)
	var person := patient.person
	var male := patient.sex() == "m"
	var words := {"He": "He" if male else "She", "he": "he" if male else "she", "himself": "himself" if male else "herself",
		"called": patient.called()}
	var what := str(patient.condition.get("plain", "the trouble"))
	words["what"] = what.substr(0, 1).to_upper() + what.substr(1)
	words["what_low"] = what
	var templates: Array = THANKS_HOME if str(patient.condition.get("go", "")) == "home" else THANKS_WARD
	var sender := ""
	if not patient.company.is_empty():
		# Whoever came in with them writes.
		sender = str(patient.company.get("full", "A relative"))
		words["relation"] = str(patient.company.get("relation", "family"))
	else:
		var relation := ""
		if patient.age < 18:
			relation = "mother" if rng.chance(0.6) else "father"
		elif patient.age >= 60:
			relation = "daughter" if rng.chance(0.5) else "son"
		elif patient.age >= 25 and rng.chance(0.6):
			relation = "wife" if male else "husband"
		if relation.is_empty():
			sender = str(person.get("full", patient.called()))
			templates = THANKS_SELF
		else:
			var sex := "f" if relation in ["mother", "daughter", "wife"] else "m"
			var age := patient.age + 28 if relation in ["mother", "father"] else (patient.age - 30 if relation in ["daughter", "son"] else patient.age)
			var family := NameMaker.make(rng, sex, clampi(age, 20, 80), str(person.get("community", "")), str(person.get("last", "")))
			sender = str(family.get("full", "A relative"))
			words["relation"] = relation
	words["sender"] = sender
	var text := str(rng.pick(templates)).format(words)
	var id := "k%d_%d" % [day, patient.id]
	return {"id": id, "chat": id, "from": id, "name": sender, "text": text, "day": day,
		"at": maxi(profile.minutes, 21 * 60) + rng.next_int_in(5, 50)}


## Dr. Iyer's message about M&M on a day a patient died of a mistake (the
## doctor's, the lab's or the team's), or {}. Nobody's-fault deaths get no
## meeting, only the wall.
static func mortality(profile: PlayerProfile, day: int, sim: ShiftSim) -> Dictionary:
	if sim == null:
		return {}
	var lines: Dictionary = Fates.data().get("mm", {})
	for patient: ShiftPatient in sim.patients:
		if patient.outcome == "died" and lines.has(patient.fault):
			var rng := SeededRandom.new(_roll(profile, "mm", day))
			var text := str(rng.pick(lines[patient.fault])).replace("{patient}", patient.called())
			return {"id": "mm%d_%d" % [day, patient.id], "chat": "iyer", "from": "iyer", "name": "", "text": text,
				"day": day, "at": maxi(profile.minutes, 21 * 60) + rng.next_int_in(55, 90)}
	return {}
