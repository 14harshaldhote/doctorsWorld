extends TestCase
## The doctor's phone (stage 23): messages that arrive on their day and
## time, replies, calls that ring only when the doctor is free, the lab,
## the pager, the feed and the camera roll, the game's own messages made
## from what really happened, and a save that can't be edited into a mess.

const CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav", "Gentle",
	"Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"]
const STEP := 1.0 / 30.0


func cleanup() -> void:
	super.cleanup()
	FrameBudget.reset()
	PhoneBook.forget()


func _doctor(day: int = 1, minutes: int = 7 * 60) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.minutes = minutes
	doctor.opening_seen = true
	doctor.created = true
	PhoneBook.forget()
	return doctor


func _ids(items: Array) -> Array:
	return items.map(func(item: Dictionary) -> String: return str(item["id"]))


func _item(profile: PlayerProfile, id: String) -> Dictionary:
	for item: Dictionary in PhoneBook.items(profile):
		if item["id"] == id:
			return item
	return {}


func _hud(doctor: PlayerProfile) -> LobbyHud:
	return add_node(LobbyHud.new(doctor)) as LobbyHud


## Ticks the HUD as the engine would, a second at a time.
func _seconds(hud: LobbyHud, seconds: int) -> void:
	for second in seconds:
		hud._process(1.0)


func _button(root: Node, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## Every script and story file except the phone's own data, as one text.
func _everything_else() -> String:
	var text := PackedStringArray()
	var files: Array[String] = []
	_files_under("res://game", ".gd", files)
	_files_under("res://story", ".json", files)
	for path in files:
		if not path.ends_with("phone.json"):
			text.append(FileAccess.get_file_as_string(path))
	return "\n".join(text)


func _files_under(folder: String, ending: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		var plain := file.trim_suffix(".remap")
		if plain.ends_with(ending):
			into.append(folder.path_join(plain))
	for sub in DirAccess.get_directories_at(folder):
		_files_under(folder.path_join(sub), ending, into)


## True when every part of a condition can come true in the game: a flag the
## game sets, a rank there is, a message with replies, a call there is.
func _can_happen(test: String, by_id: Dictionary, calls: Dictionary, everything: String) -> bool:
	if test.is_empty():
		return true
	for part in test.replace("|", "&").split("&"):
		var token := part.trim_prefix("!")
		if token.begins_with("rank>="):
			if not token.substr(6).is_valid_int() or int(token.substr(6)) > Rank.TITLES.size() - 1:
				return false
		elif token.begins_with("r:"):
			var reply := token.substr(2).split("=")
			if not by_id.has(reply[0]) or (by_id[reply[0]].get("reply", []) as Array).is_empty():
				return false
		elif token.begins_with("c:"):
			if not calls.has(token.substr(2).split("=")[0]):
				return false
		elif not everything.contains("\"%s\"" % token):
			return false
	return true


func _ward(day: int = 4) -> Ward:
	var doctor := _doctor(day)
	doctor.total_xp = 800
	doctor.set_count("hospital_seed", 4242)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


# --- What the phone holds -----------------------------------------------------------

func test_every_message_call_and_post_is_whole() -> void:
	var data := PhoneBook.data()
	for key: String in ["contacts", "chats", "calls", "feed", "photos", "lab"]:
		expect(data.has(key), "the phone's data has %s" % key)
	var people := PhoneBook.contacts()
	expect(people.size() >= 20, "a phone full of people (%d)" % people.size())
	for id: String in people:
		var person: Dictionary = people[id]
		expect(PhoneBook._good_id(id), "contact id %s" % id)
		expect(not str(person.get("name", "")).is_empty(), "%s has a name" % id)
		expect(Color.html_is_valid(str(person.get("colour", ""))), "%s has a colour" % id)
		for member: Variant in person.get("group", []):
			expect(people.has(member) and not (people[member] as Dictionary).has("group"),
				"%s: %s is a person on the phone" % [id, member])
	var chats: Array = data["chats"]
	expect(chats.size() >= 100, "plenty to read (%d messages)" % chats.size())
	var by_id := {}
	for entry: Dictionary in chats:
		by_id[str(entry.get("id", ""))] = entry
	var calls := {}
	for entry: Dictionary in data["calls"]:
		calls[str(entry.get("id", ""))] = entry
	var everything := _everything_else()
	var used := {}
	for kind: String in ["chats", "calls", "feed", "photos", "lab"]:
		for entry: Dictionary in data[kind]:
			var id := str(entry.get("id", ""))
			expect(PhoneBook._good_id(id) and not "#" in id, "%s: id '%s'" % [kind, id])
			expect(not used.has(id), "%s is used once" % id)
			used[id] = true
			var when := str(entry.get("when", ""))
			expect(_can_happen(when, by_id, calls, everything), "%s: its condition '%s' can come true" % [id, when])
			if entry.has("photo"):
				expect(str(entry["photo"]) in PhotoCard.KINDS, "%s: a photo the phone can draw (%s)" % [id, entry["photo"]])
			if entry.has("answer_to"):
				continue
			var day := int(entry.get("day", 0))
			expect(day >= 1 and day <= DayHooks.LAST_STORY_DAY, "%s: day %d" % [id, day])
			var at := str(entry.get("at", ""))
			expect(at.length() == 5 and at[2] == ":" and PhoneBook.parse_at(at) < 33 * 60, "%s: at '%s'" % [id, at])
	for entry: Dictionary in chats:
		var id := str(entry["id"])
		var chat := str(entry.get("chat", ""))
		var from := str(entry.get("from", ""))
		expect(people.has(chat), "%s: chat %s is on the phone" % [id, chat])
		if PhoneBook.is_group(chat):
			expect(from in (people[chat]["group"] as Array), "%s: %s is in %s" % [id, from, chat])
		else:
			expect(from == chat, "%s: a one-to-one chat is written by its person" % id)
		var said := str(entry.get("text", "")) + str(entry.get("photo", ""))
		expect(not said.is_empty() or bool(entry.get("deleted", false)), "%s says something" % id)
		expect(str(entry.get("text", "")).length() <= 240, "%s fits on a phone" % id)
		if entry.has("reply"):
			var replies: Array = entry["reply"]
			expect_equal(replies.size(), 2, "%s: two replies" % id)
			for reply: Variant in replies:
				expect(not str(reply).is_empty() and str(reply).length() <= 60, "%s: a reply that fits a chip: %s" % [id, reply])
		if entry.has("answer_to"):
			var to: Dictionary = by_id.get(str(entry["answer_to"]), {})
			var offered: Array = to.get("reply", [])
			expect(not offered.is_empty(), "%s answers a message with replies" % id)
			expect(str(to.get("chat", "")) == chat, "%s answers in the same chat" % id)
			expect(int(entry.get("pick", 0)) < offered.size(), "%s: its pick is one of the replies" % id)
	var cast := StoryBook.cast()
	for entry: Dictionary in data["calls"]:
		var id := str(entry["id"])
		var from := str(entry.get("from", ""))
		expect(people.has(from), "%s: the caller is on the phone" % id)
		var voices: Array = (people.get(from, {}) as Dictionary).get("group", [from])
		var lines: Array = (entry.get("lines", []) as Array).duplicate()
		expect(not lines.is_empty() or bool(entry.get("busy", false)), "%s: something is said, unless nobody can pick up" % id)
		var replies: Array = entry.get("reply", [])
		var after: Array = entry.get("after", [])
		expect(after.is_empty() or after.size() == replies.size(), "%s: what they say after each reply" % id)
		for more: Array in after:
			lines.append_array(more)
		for line: Dictionary in lines:
			var who := str(line.get("say", ""))
			expect(who in voices, "%s: %s is on the line" % [id, who])
			expect(cast.has(who), "%s: %s speaks in their own voice (a cast member)" % [id, who])
			expect(not str(line.get("text", "")).is_empty(), "%s: a line with words" % id)
		expect(not str(entry.get("missed", "")).is_empty(), "%s leaves a message when nobody answers" % id)
	for entry: Dictionary in data["feed"]:
		expect(people.has(str(entry.get("from", ""))), "%s: the poster is on the phone" % entry["id"])
		expect(not str(entry.get("text", "")).is_empty(), "%s says something" % entry["id"])
	for entry: Dictionary in data["photos"]:
		expect(not str(entry.get("photo", "")).is_empty(), "%s is a photo" % entry["id"])
	for entry: Dictionary in data["lab"]:
		for field: String in ["patient", "test", "result"]:
			expect(not str(entry.get(field, "")).is_empty(), "%s has its %s" % [entry["id"], field])


func test_the_phone_keeps_real_names_out() -> void:
	var text := FileAccess.get_file_as_string(PhoneBook.PATH)
	expect(not text.to_lower().contains("harshal"), "the developer's name stays out")
	var asha := RegEx.create_from_string("\\bAsha\\b")
	expect(asha.search(text) == null, "nobody on the phone is called Asha")
	# The game's own messages: [who, text, ...] from people on the phone.
	for list: Array in [PhoneWriter.HOME, PhoneWriter.HOME_GENTLE, PhoneWriter.BATCH_AHEAD, PhoneWriter.BATCH_BEHIND,
			PhoneWriter.BATCH_IDLE]:
		for entry: Array in list:
			expect(PhoneBook.contacts().has(str(entry[0])), "the game's messages come from people on the phone: %s" % entry[0])
	var written := JSON.stringify([PhoneWriter.REELS, PhoneWriter.HOME, PhoneWriter.HOME_GENTLE, PhoneWriter.BATCH_AHEAD,
		PhoneWriter.BATCH_BEHIND, PhoneWriter.BATCH_IDLE, PhoneWriter.HOSPITAL_POSTS, PhoneWriter.NEWS_POSTS,
		PhoneWriter.THANKS_HOME, PhoneWriter.THANKS_WARD, PhoneWriter.THANKS_SELF])
	expect(not written.to_lower().contains("harshal") and asha.search(written) == null, "nor in the game's own messages")


func test_every_photo_is_a_picture_the_phone_can_draw() -> void:
	for kind: String in PhotoCard.KINDS:
		var card := PhotoCard.make(kind, Vector2(120, 90), 7)
		expect(card.kind == kind and card.custom_minimum_size == Vector2(120, 90), kind)
		expect_equal(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a picture doesn't take taps")
		card.free()
	expect_equal(PhotoCard.make("not a kind", Vector2(10, 10)).kind, "hospital", "a photo the game can't draw shows the hospital")
	for entry: Array in PhoneWriter.REELS:
		expect(str(entry[1]) in PhotoCard.KINDS, "Varun's reel: %s" % entry[1])
	for entry: Array in PhoneWriter.HOME:
		expect(str(entry[2]).is_empty() or str(entry[2]) in PhotoCard.KINDS, "home: %s" % entry[2])
	for entry: Array in PhoneWriter.HOSPITAL_POSTS:
		expect(str(entry[1]) in PhotoCard.KINDS, "the hospital's page: %s" % entry[1])


# --- Arriving, reading and answering --------------------------------------------------

func test_messages_arrive_on_their_day_at_their_time() -> void:
	var doctor := _doctor(1, 6 * 60)
	expect(not "d1_mum" in _ids(PhoneBook.arrived(doctor, "chat")), "Mum's 06:30 message isn't there at six")
	doctor.minutes = 6 * 60 + 30
	expect("d1_mum" in _ids(PhoneBook.arrived(doctor, "chat")), "it arrives at 06:30")
	expect(str(PhoneBook.thread(doctor, "family")[0]["text"]).begins_with("Reached?"), "first in the family group")
	expect(not "d1_varun_dm" in _ids(PhoneBook.arrived(doctor, "chat")), "Varun waits for 17:30")
	doctor.day = 2
	expect("d1_varun_dm" in _ids(PhoneBook.arrived(doctor, "chat")), "and turns up the next day if Day 1 ended before then")
	var last := -1
	for item: Dictionary in PhoneBook.arrived(doctor):
		expect(int(item["stamp"]) >= last, "oldest first")
		last = int(item["stamp"])
	doctor.day = 4
	var arrived := _ids(PhoneBook.arrived(doctor, "chat"))
	expect("d3_sunita" in arrived and not "d3_sunita_icu" in arrived, "Rohit's mother asks about ice cream after a good operation")
	doctor.set_flag("op_rohit_failed")
	PhoneBook.forget()
	arrived = _ids(PhoneBook.arrived(doctor, "chat"))
	expect("d3_sunita_icu" in arrived and not "d3_sunita" in arrived, "and writes from the ICU after a bad one")
	for item: Dictionary in PhoneBook.items(doctor):
		expect(not str(item["text"]).contains("{") and not str(item["caption"]).contains("{"),
			"%s has every name filled in" % item["id"])


func test_conditions_read_flags_ranks_replies_and_calls() -> void:
	var doctor := _doctor(5)
	expect(PhoneBook.holds(doctor, ""), "no condition always holds")
	expect(not PhoneBook.holds(doctor, "beds_agreed") and PhoneBook.holds(doctor, "!beds_agreed"))
	doctor.set_flag("beds_agreed")
	expect(PhoneBook.holds(doctor, "beds_agreed&!kunal_room"), "and")
	expect(PhoneBook.holds(doctor, "kunal_room|beds_agreed"), "or")
	expect(not PhoneBook.holds(doctor, "kunal_room&beds_agreed"))
	expect(not PhoneBook.holds(doctor, "rank>=2"), "an intern isn't a senior")
	doctor.rank_held = 2
	expect(PhoneBook.holds(doctor, "rank>=2") and not PhoneBook.holds(doctor, "rank>=3"), "ranks")
	expect(not PhoneBook.holds(doctor, "r:d1_mum"), "not answered yet")
	PhoneBook.state(doctor)["replies"]["d1_mum"] = [1, PhoneBook.stamp(1, 400)]
	expect(PhoneBook.holds(doctor, "r:d1_mum") and PhoneBook.holds(doctor, "r:d1_mum=1") and not PhoneBook.holds(doctor, "r:d1_mum=0"),
		"which reply")
	expect(PhoneBook.holds(doctor, "c:d1_mum_call=d") and not PhoneBook.holds(doctor, "c:d1_mum_call=a"), "a call not answered")
	PhoneBook.record_call(doctor, "d1_mum_call", "a", 0)
	expect(PhoneBook.holds(doctor, "c:d1_mum_call=a") and PhoneBook.holds(doctor, "c:d1_mum_call"), "and answered")
	expect_equal(PhoneBook.fill(doctor, "{first}, {called}, {title}"), "Asha, Dr. Verma, Dr. Asha Verma")


func test_answering_a_message_puts_the_reply_in_the_chat_and_they_answer_back() -> void:
	var doctor := _doctor(1, 6 * 60 + 40)
	expect_equal(str(PhoneBook.pending_reply(doctor, "family").get("id", "")), "d1_mum", "Mum's question waits for an answer")
	expect(not PhoneBook.answer(doctor, "d1_mum", 2), "only the replies offered")
	expect(not PhoneBook.answer(doctor, "d1_mum", -1))
	expect(not PhoneBook.answer(doctor, "d1_varun_dm", 0), "not a message that hasn't arrived")
	expect(not PhoneBook.answer(doctor, "d1_dad2", 0), "not a message with nothing to say back")
	expect(PhoneBook.answer(doctor, "d1_mum", 1), "an answer")
	expect(not PhoneBook.answer(doctor, "d1_mum", 0), "once")
	expect(PhoneBook.pending_reply(doctor, "family").is_empty(), "nothing left to answer")
	var thread := _ids(PhoneBook.thread(doctor, "family"))
	expect("d1_mum#you" in thread, "the doctor's reply is in the chat")
	expect_equal(_item(doctor, "d1_mum#you")["text"], "It's in the bag. I'll eat at lunch.")
	expect(not "d1_mum_b" in thread, "Mum takes a minute")
	expect(not "d1_mum_a" in _ids(PhoneBook.items(doctor)), "and answers only what was said")
	doctor.minutes += 1
	thread = _ids(PhoneBook.thread(doctor, "family"))
	expect("d1_mum_b" in thread and thread.find("d1_mum_b") > thread.find("d1_mum#you"), "then answers back, after it")


func test_a_new_career_reads_from_day_one_and_an_old_save_starts_today() -> void:
	var fresh := _doctor(1, 7 * 60)
	var unread := PhoneBook.unread_in(fresh, "family")
	expect(unread >= 3, "Mum, Dad and Anu wrote before the first shift (%d)" % unread)
	expect_equal(PhoneBook.badge(fresh), PhoneBook.app_unread(fresh, "chats"), "the badge counts them")
	PhoneBook.mark_seen(fresh, "c:family")
	expect_equal(PhoneBook.unread_in(fresh, "family"), 0, "reading the chat reads it all")
	fresh.minutes = 17 * 60 + 30
	expect_equal(PhoneBook.unread_in(fresh, "varun"), 1, "a new one later is new")
	var old := _doctor(12, 7 * 60)
	for entry: Dictionary in PhoneBook.chats(old):
		if int(entry["unread"]) > 0:
			expect_equal(int(entry["last"]["day"]), 12, "a save from before the phone starts with only today's unread")
	expect_equal(PhoneBook.missed_unseen(old), 0, "and no pile of missed calls")
	expect(PhoneBook.chats(old).size() >= 8, "but every old chat is there to scroll back through")


# --- Calls ----------------------------------------------------------------------------

func test_calls_ring_once_and_a_missed_one_leaves_a_message() -> void:
	var doctor := _doctor(1, 7 * 60)
	expect(PhoneBook.call_due(doctor).is_empty(), "nobody calls before 07:15")
	doctor.minutes = 7 * 60 + 15
	expect_equal(str(PhoneBook.call_due(doctor).get("id", "")), "d1_mum_call", "Mum calls at 07:15")
	expect(PhoneBook.call_log(doctor).is_empty(), "a call that hasn't rung isn't in the log")
	var badge := PhoneBook.badge(doctor)
	PhoneBook.record_call(doctor, "d1_mum_call", "m")
	expect(PhoneBook.call_due(doctor).is_empty(), "it rings once")
	var log := PhoneBook.call_log(doctor)
	expect(log.size() == 1 and log[0]["state"] == "missed", "missed, in the log")
	expect_equal(PhoneBook.missed_unseen(doctor), 1)
	expect_equal(PhoneBook.badge(doctor), badge + 1, "on the badge")
	expect(not "d1_mum_call#left" in _ids(PhoneBook.thread(doctor, "mum")), "her message comes a minute or two later")
	doctor.minutes += 2
	expect("d1_mum_call#left" in _ids(PhoneBook.thread(doctor, "mum")), "Mum texts instead")
	PhoneBook.mark_seen(doctor, "calls")
	expect_equal(PhoneBook.missed_unseen(doctor), 0, "looking at Calls clears it")
	PhoneBook.record_call(doctor, "d1_mum_call", "x")
	expect_equal(str(doctor.phone["calls"]["d1_mum_call"][0]), "m", "only real outcomes are kept")

	var answered := _doctor(1, 7 * 60 + 20)
	PhoneBook.record_call(answered, "d1_mum_call", "a", 0)
	expect_equal(PhoneBook.call_log(answered)[0]["state"], "answered")
	answered.minutes += 5
	expect(not "d1_mum_call#left" in _ids(PhoneBook.items(answered)), "an answered call leaves no message")

	var theatre := _doctor(3, 11 * 60)
	expect(PhoneBook.call_due(theatre).is_empty(), "Mum's call during the operation never rings")
	var busy := PhoneBook.call_log(theatre).filter(func(item: Dictionary) -> bool: return item["id"] == "d3_mum_busy")
	expect(busy.size() == 1 and busy[0]["state"] == "missed", "it's simply missed")
	expect("d3_mum_busy#left" in _ids(PhoneBook.thread(theatre, "mum")), "with a sorry-sorry message")

	var next_day := _doctor(2, 7 * 60)
	expect_equal(PhoneBook.call_log(next_day)[0]["state"], "missed", "a call the day never got to is missed")

	var chief := _doctor(28, 7 * 60)
	chief.rank_held = 5
	var left := _item(chief, "d27_family_call#left")
	expect(not left.is_empty() and left["chat"] == "family" and left["from"] == "mum", "the family's missed call: Mum types in the group")


# --- Saves ------------------------------------------------------------------------------

func test_the_phone_is_saved_and_comes_back() -> void:
	var doctor := _doctor(2, 9 * 60)
	expect(PhoneBook.answer(doctor, "d1_mum", 0))
	PhoneBook.record_call(doctor, "d1_mum_call", "a", 1)
	PhoneBook.mark_seen(doctor, "c:family")
	var back := PlayerProfile.from_dict(doctor.to_dict())
	expect_equal(back.phone, doctor.phone, "kept as it was")
	var through_json := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(doctor.to_dict())))
	expect_equal(through_json.phone, doctor.phone, "and through a save file")
	PhoneBook.forget()
	expect("d1_mum#you" in _ids(PhoneBook.thread(through_json, "family")), "the reply is still in the chat")
	expect_equal(PhoneBook.unread_in(through_json, "family"), 0, "still read")
	var older := doctor.to_dict()
	older.erase("phone")
	expect(PlayerProfile.from_dict(older).phone.is_empty(), "a save from before the phone has none")


func test_an_edited_save_cant_break_the_phone() -> void:
	expect(PhoneBook.clean("junk").is_empty() and PhoneBook.clean(null).is_empty() and PhoneBook.clean([1, 2]).is_empty(),
		"not a phone at all")
	var kept: Array = ["junk", {"id": "bad id!", "chat": "x", "from": "x", "day": 3, "at": 60},
		{"id": "k4_2", "chat": "k4_2", "from": "k4_2", "name": "x".repeat(5000), "text": "y".repeat(5000), "day": 4, "at": 99999}]
	for index in 20:
		kept.append({"id": "k5_%d" % index, "chat": "k5_%d" % index, "from": "k5_%d" % index, "name": "Sender", "text": "Thanks",
			"day": 5, "at": 1300})
	var days := {"3": {"lost": "yes", "xp": 1e12, "lead": "far"}, "not a day": {}, "4": []}
	for day in range(5, 20):
		days[str(day)] = {"lost": true, "xp": 10}
	var seen := {"c:family": 1e15, "../../etc": 5, "c:varun": -4, "c:mum": "lots", "*": 3.7}
	for index in PhoneBook.SEEN_MAX + 50:
		seen["c:k%d" % index] = 1
	var cleaned := PhoneBook.clean({
		"seen": seen,
		"replies": {"d1_mum": [9, 5], "d1_dad": [0], "<script>": [0, 0], "d2_priya": "yes", "d4_arjun": [1.0, 40042.0]},
		"calls": {"d1_mum_call": ["x", 1, 0], "d19_dad_call": ["a", 5, 99], "d22_mum_call": ["m", -3, -9], "d3": "a"},
		"kept": kept,
		"days": days,
		"extra": "ignored",
	})
	expect(not cleaned.has("extra"), "nothing that isn't the phone's")
	expect_equal(cleaned["seen"].size(), PhoneBook.SEEN_MAX, "no more read marks than a phone could have")
	expect_equal(cleaned["seen"]["c:family"], 100000 * PhoneBook.STAMP_DAY, "a stamp from the far future is held back")
	expect(not cleaned["seen"].has("../../etc"), "only the phone's own names")
	expect(not cleaned["seen"].has("c:varun") and not cleaned["seen"].has("c:mum"), "no negative or made-up stamps")
	expect_equal(cleaned["seen"]["*"], 3)
	expect_equal(cleaned["replies"]["d1_mum"], [3, 5], "a pick past the replies is held in")
	expect_equal(cleaned["replies"]["d4_arjun"], [1, 40042], "numbers from a save file come back whole")
	for gone: String in ["d1_dad", "<script>", "d2_priya"]:
		expect(not cleaned["replies"].has(gone), "%s dropped" % gone)
	expect(not cleaned["calls"].has("d1_mum_call") and not cleaned["calls"].has("d3"), "made-up call outcomes dropped")
	expect_equal(cleaned["calls"]["d19_dad_call"], ["a", 5, 3])
	expect_equal(cleaned["calls"]["d22_mum_call"], ["m", 0, -1])
	expect(cleaned["kept"].size() <= PhoneBook.KEPT_MAX, "no more kept messages than the phone keeps")
	for entry: Dictionary in cleaned["kept"]:
		expect(PhoneBook._good_id(entry["id"]), "kept ids are the phone's own")
		expect(str(entry["text"]).length() <= PhoneBook.TEXT_MAX and str(entry["name"]).length() <= PhoneBook.TEXT_MAX, "short")
		expect(int(entry["at"]) <= 48 * 60, "a real time")
	expect(cleaned["days"].size() <= PhoneBook.DAYS_MAX, "only the last few days")
	expect(not cleaned["days"].has("not a day") and not cleaned["days"].has("4"), "only real day notes")
	var loaded_data := _doctor(6).to_dict()
	loaded_data["phone"] = {"seen": "x", "replies": [1], "calls": {"d1_mum_call": ["a", "b", "c"]}, "kept": {"a": 1}, "days": 4}
	var loaded := PlayerProfile.from_dict(loaded_data)
	PhoneBook.forget()
	expect(PhoneBook.badge(loaded) >= 0 and PhoneBook.items(loaded).size() > 50, "a nonsense phone loads as an empty one")


# --- The game's own messages --------------------------------------------------------------

func test_the_games_own_messages_are_fixed_for_a_career_and_a_day() -> void:
	expect(PhoneWriter.items(_doctor(1)).is_empty(), "Day 1 is all the story's")
	var doctor := _doctor(12, 22 * 60)
	var first := PhoneWriter.items(doctor)
	expect_equal(first, PhoneWriter.items(_doctor(12, 22 * 60)), "the same career sees the same messages")
	var other := _doctor(12, 22 * 60)
	other.name = "Ravi Menon"
	var texts := first.map(func(item: Dictionary) -> String: return str(item["text"]))
	var other_texts := PhoneWriter.items(other).map(func(item: Dictionary) -> String: return str(item["text"]))
	expect(texts != other_texts, "another career sees others")
	var ids := {}
	var story_home := {}
	for entry: Dictionary in PhoneBook.data()["chats"]:
		if str(entry.get("chat", "")) in ["family", "mum", "dad", "anu"] and not entry.has("answer_to"):
			story_home[int(entry.get("day", 0))] = true
	for item: Dictionary in first:
		var day := int(item["day"])
		expect(day > 12 - PhoneBook.WINDOW and day <= 12, "%s: from the last week" % item["id"])
		expect(not ids.has(item["id"]), "%s once" % item["id"])
		ids[item["id"]] = true
		expect(PhoneBook.contacts().has(str(item["from"])), "%s from someone on the phone" % item["id"])
		expect(not str(item["text"]).contains("{") and not str(item["text"]).contains("%"), "%s filled in" % item["id"])
		if str(item["id"]).begins_with("gen_home_"):
			expect(not story_home.has(day), "home writes only on days the story doesn't (%d)" % day)
			expect(int(item["at"]) >= 20 * 60 + 30, "in the evening")
		if str(item["id"]).begins_with("gen_reel_"):
			expect(day >= Rival.FIRST_DAY, "Varun's reels start with the race")
	var chief := _doctor(41, 12 * 60)
	var feed := _ids(PhoneWriter.items(chief))
	expect("gen_page_41" in feed, "after the story the hospital posts on its own")
	expect("gen_news_40" in feed, "and so does the paper")


func test_a_hard_day_and_the_race_change_the_evening_messages() -> void:
	var doctor := _doctor(11, 12 * 60)
	var calm := PhoneWriter.home(doctor, 10)
	PhoneBook.state(doctor)["days"]["10"] = {"lost": true, "xp": 0, "seen": 0, "right": 0, "lead": 0}
	var gentle := PhoneWriter.home(doctor, 10)
	var soft := PhoneWriter.HOME_GENTLE.map(func(entry: Array) -> String: return str(entry[1]))
	expect(str(gentle["text"]) in soft, "after losing a patient, home is gentle")
	expect(not str(calm["text"]) in soft, "not otherwise")
	PhoneBook.state(doctor)["days"]["9"] = {"lost": false, "xp": 300, "seen": 3, "right": 3, "lead": 80}
	expect(str(PhoneWriter.batch(doctor, 9)["text"]).contains("80"), "the batch group knows who's ahead")
	PhoneBook.state(doctor)["days"]["9"]["lead"] = -45
	expect(str(PhoneWriter.batch(doctor, 9)["text"]).contains("45"), "and by how much")


func test_a_patient_casualty_sent_home_well_may_send_a_thank_you() -> void:
	var sim := ShiftSim.new(77, 8 * 60)
	var skipped: Array[int] = []
	for id: String in ["renal_colic", "asthma", "gastro", "ectopic", "brain_bleed"]:
		var patient := sim.make_patient(id)
		sim.patients.append(patient)
		patient.state = "seeing"
		sim.decide(patient, ShiftBot.position_of(patient, true))
		expect_equal(patient.outcome, "better", "%s treated well" % id)
		if id in ["ectopic", "brain_bleed"]:
			skipped.append(patient.id)
	var doctor := _doctor(9, 19 * 60)
	var found := {}
	var on_day := 0
	var empty_days := 0
	for day in range(9, 40):
		var thanks := PhoneWriter.thanks(doctor, day, sim)
		if thanks.is_empty():
			empty_days += 1
			continue
		expect_equal(thanks, PhoneWriter.thanks(doctor, day, sim), "the same every time")
		expect(not str(thanks["text"]).contains("{"), "filled in: %s" % thanks["text"])
		expect(not str(thanks["name"]).is_empty() and not str(thanks["name"]).contains("Asha"), "from someone with a name")
		expect(int(thanks["id"].split("_")[1]) not in skipped, "never about a miscarriage or a brain bleed")
		expect(int(thanks["at"]) >= 21 * 60, "tonight")
		expect(PhoneBook._good_id(thanks["id"]), "an id the save keeps")
		if found.is_empty():
			found = thanks
			on_day = day
	expect(not found.is_empty() and empty_days > 0, "some days someone writes, some days nobody does")
	expect(PhoneWriter.thanks(doctor, 9, null).is_empty(), "no casualty, no thank-you")
	var nobody := ShiftSim.new(3, 8 * 60)
	expect(PhoneWriter.thanks(doctor, 9, nobody).is_empty(), "nobody treated, nobody writes")
	doctor.day = on_day
	doctor.minutes = 19 * 60
	PhoneBook.note_day(doctor, on_day, sim)
	PhoneBook.note_day(doctor, on_day, sim)
	var kept: Array = doctor.phone["kept"]
	expect_equal(kept.size(), 1, "kept once, however often the day is noted")
	expect(PhoneBook.state(doctor)["days"].has(str(on_day)), "the day is remembered")
	doctor.day = on_day + 1
	PhoneBook.forget()
	var chat := str(found["chat"])
	expect(chat in PhoneBook.chats(doctor).map(func(entry: Dictionary) -> String: return str(entry["chat"])), "it's in Chats the next morning")
	expect_equal(PhoneBook.contact_name(chat, PhoneBook.thread(doctor, chat)[0]), str(found["name"]), "under the sender's name")


func test_the_end_of_day_card_says_who_is_about_to_text() -> void:
	var doctor := _doctor(3, 18 * 60 + 30)
	doctor.set_flag("op_rohit_won")
	var line := PhoneBook.evening_line(doctor, 3)
	expect(line.begins_with("Phone: ") and line.contains("Varun"), line)
	var post := Letters.post_line(doctor, 3)
	expect_equal(str(DayHooks.end_card(doctor, 3)["post"]), post if not post.is_empty() else line, "on the card, unless a letter waits")
	doctor.day = 4
	expect_equal(PhoneBook.evening_line(doctor, 3), "", "nothing once it has all arrived")


func test_casualty_results_land_in_the_lab_app() -> void:
	var doctor := _doctor(9, 11 * 60)
	expect(PhoneBook.casualty_lab(doctor, null).is_empty(), "no casualty, no results")
	var sim := ShiftSim.new(5, 8 * 60)
	var patient := sim.make_patient("dka")
	sim.patients.append(patient)
	patient.ordered["sugar"] = 10 * 60 + 40
	patient.results["sugar"] = "Sugar 540, ketones high"
	patient.ordered["ecg"] = 11 * 60 + 30
	var results := PhoneBook.casualty_lab(doctor, sim)
	expect_equal(results.size(), 1, "only the results that are back")
	var item: Dictionary = results[0]
	expect_equal(item["patient"], "%s, %d" % [patient.called(), patient.age])
	expect_equal(item["test"], str(Conditions.TESTS["sugar"]["name"]))
	expect_equal(item["result"], "Sugar 540, ketones high")
	expect_equal(item["high"], (patient.condition.get("results", {}) as Dictionary).has("sugar"), "flagged when it matters")
	expect_equal(PhoneBook.clock(int(item["stamp"])), "10:40", "when it came back")
	var shown := _ids(PhoneBook.lab(doctor, results))
	expect(shown[0] == item["id"], "newest first")


# --- On the screen -------------------------------------------------------------------------

func test_the_phone_button_brings_the_phone_up_and_puts_it_away() -> void:
	tree.root.size = Vector2i(1688, 780)
	FrameBudget.reset()
	var doctor := _doctor(1, 8 * 60)
	var hud := _hud(doctor)
	expect(hud.phone_badge() != "", "messages waiting show on the Phone button")
	var button := _button(hud.get_node("Buttons"), "Phone")
	button.pressed.emit()
	var phone := hud.phone_panel()
	expect(phone != null, "the phone comes up")
	expect_equal(FrameBudget.calm_screens(), 1, "and the game asks for 30 frames a second")
	for app: String in ["chats", "calls", "lab", "pager", "feed", "photos"]:
		var icon := _button(phone, "App_" + app)
		expect(icon != null and icon.custom_minimum_size.y >= UiKit.px(44), "%s, big enough to tap" % app)
	expect(phone.find_child("Recent", true, false) != null, "the latest messages under the apps")
	expect(not hud.menu_open(), "the hospital doesn't stop for a phone")
	phone._layout()  # where it ends up once it has slid in
	var screen := hud.get_viewport().get_visible_rect()
	var body := Rect2(phone.body.global_position, phone.body.size)
	expect(screen.grow(1.0).encloses(body), "on the screen: %s in %s" % [body, screen])
	button.pressed.emit()
	expect(not hud.phone_open(), "the Phone button puts it away")
	expect_equal(FrameBudget.calm_screens(), 0, "full speed again at once")
	expect(hud.open_phone() != null)
	_button(hud.get_node("Buttons"), "Career").pressed.emit()
	expect(not hud.phone_open() and hud.career_map() != null, "the other buttons put it away first")
	hud.career_map().close()


func test_reading_and_answering_a_chat_on_the_phone() -> void:
	var doctor := _doctor(1, 8 * 60 + 30)
	var hud := _hud(doctor)
	var phone := hud.open_phone()
	_button(phone, "App_chats").pressed.emit()
	expect_equal(phone.page, "chats")
	expect(phone.find_child("Chat_family", true, false) != null, "the family group")
	expect(phone.find_child("Chat_batch", true, false) != null, "and the batch group")
	phone.open_chat("family")
	expect_equal(phone.page, "chat")
	expect(phone.find_child("Msg_d1_mum", true, false) != null, "Mum's message")
	var dad := phone.find_child("Msg_d1_dad", true, false)
	expect(dad != null and dad.find_child("Photo", true, false) != null, "Dad's good-morning photo")
	expect_equal(PhoneBook.unread_in(doctor, "family"), 0, "opening it reads it")
	expect_equal(phone.reply_texts().size(), 2, "two things to say back")
	_button(phone, "Reply0").pressed.emit()
	expect(phone.find_child("Msg_d1_mum_you", true, false) != null, "the answer shows as the doctor's own bubble")
	expect(phone.find_child("NoReply", true, false) != null, "nothing more to say")
	doctor.minutes += 2
	phone._process(PhonePanel.CHECK_EVERY + 0.1)
	expect(phone.find_child("Msg_d1_mum_a", true, false) != null, "Mum answers while it's open")
	phone.back()
	expect_equal(phone.page, "chats", "back to the chats")
	phone.back()
	expect_equal(phone.page, "home")
	phone.home_pressed()
	expect(not hud.phone_open(), "the bar at the bottom of the home screen puts it away")


func test_a_call_rings_when_the_doctor_is_free_and_can_be_answered() -> void:
	var doctor := _doctor(1, 7 * 60 + 15)
	var hud := _hud(doctor)
	hud.set_talking(true)
	_seconds(hud, 10)
	expect(hud.ringing.is_empty(), "never in the middle of a conversation")
	hud.set_talking(false)
	_seconds(hud, 3)
	expect(hud.ringing.is_empty(), "it waits until the doctor has been free a moment")
	_seconds(hud, 5)
	expect_equal(str(hud.ringing.get("id", "")), "d1_mum_call", "then Mum rings")
	expect(hud.banner_text().begins_with("Mum"), hud.banner_text())
	hud.toggle_phone()
	expect(not hud.phone_open() or hud.phone_panel().call_phase != "talking", "the Phone button doesn't pick up by itself")
	hud.answer_ringing()
	var phone := hud.phone_panel()
	expect(phone != null and phone.page == "call" and phone.call_phase == "talking", "answered on the phone")
	expect(phone.find_child("EndCall", true, false) != null, "with a button to hang up")
	expect(hud.banner_text().is_empty(), "the banner goes")
	phone.back()
	phone.home_pressed()
	expect_equal(phone.page, "call", "a call can't be walked away from by accident")
	for step in 100:
		if phone.call_phase == "choosing":
			break
		phone.skip_call_line()
		phone._process(0.1)
	expect_equal(phone.call_phase, "choosing", "Mum asks how it's going")
	expect(phone.call_caption().begins_with("Mum: "), phone.call_caption())
	_button(phone, "CallReply1").pressed.emit()
	expect_equal(phone.call_phase, "after")
	phone._process(0.2)
	expect(phone.call_caption().begins_with("You: "), "the doctor's words show (the doctor is never heard)")
	for step in 100:
		if phone.call_phase == "ended":
			break
		phone.skip_call_line()
		phone._process(0.1)
	expect_equal(phone.page, "home", "she hangs up and the phone goes home")
	expect_equal(doctor.phone["calls"]["d1_mum_call"], ["a", PhoneBook.now(doctor), 1], "answered, with the reply")
	expect(hud.ringing.is_empty() and PhoneBook.call_due(doctor).is_empty(), "and it doesn't ring again")


func test_a_call_left_ringing_is_missed_and_one_declined_is_declined() -> void:
	var doctor := _doctor(1, 7 * 60 + 15)
	var hud := _hud(doctor)
	_seconds(hud, 8)
	expect(not hud.ringing.is_empty(), "Mum rings")
	_seconds(hud, int(LobbyHud.RING_FOR) + 1)
	expect(hud.ringing.is_empty(), "and gives up")
	expect_equal(str(doctor.phone["calls"]["d1_mum_call"][0]), "m", "missed")
	doctor.minutes += 2
	expect("d1_mum_call#left" in _ids(PhoneBook.thread(doctor, "mum")), "she texts instead")

	var later := _doctor(22, 12 * 60 + 30)
	var hud2 := _hud(later)
	_seconds(hud2, 8)
	expect_equal(str(hud2.ringing.get("id", "")), "d22_mum_call", "Mum rings about the crash on the news")
	var banner := hud2.find_child("PhoneBanner", true, false) as Control
	_button(banner, "Decline").pressed.emit()
	expect(hud2.ringing.is_empty() and str(later.phone["calls"]["d22_mum_call"][0]) == "d", "declined from the banner")

	var talking := _doctor(19, 18 * 60 + 15)
	var hud3 := _hud(talking)
	_seconds(hud3, 8)
	expect(not hud3.ringing.is_empty(), "Dad rings")
	hud3.set_talking(true)
	expect(hud3.ringing.is_empty() and str(talking.phone["calls"]["d19_dad_call"][0]) == "m",
		"someone walks up to talk: the call goes unanswered")


func test_a_new_message_shows_a_banner_that_opens_the_chat() -> void:
	var doctor := _doctor(1, 17 * 60 + 29)
	PhoneBook.record_call(doctor, "d1_mum_call", "a", 0)
	for entry: Dictionary in PhoneBook.chats(doctor):
		PhoneBook.mark_seen(doctor, "c:" + str(entry["chat"]))
	var hud := _hud(doctor)
	_seconds(hud, 3)
	expect_equal(hud.banner_text(), "", "nothing new, no banner")
	expect_equal(hud.phone_badge(), "", "and no number on the button")
	doctor.minutes = 17 * 60 + 30
	_seconds(hud, 1)
	expect(hud.banner_text().begins_with("Varun Khanna") and hud.banner_text().contains("A pager"), hud.banner_text())
	expect_equal(hud.phone_badge(), "1")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = false
	hud._on_banner_input(tap)
	var phone := hud.phone_panel()
	expect(phone != null and phone.page == "chat" and phone.page_arg == "varun", "a tap on it opens Varun's chat")
	expect_equal(PhoneBook.unread_in(doctor, "varun"), 0)
	hud.close_phone()
	_seconds(hud, 1)
	expect_equal(hud.phone_badge(), "", "read, so the number goes")
	doctor.minutes = 17 * 60 + 31
	expect(PhoneBook.answer(doctor, "d1_varun_dm", 1))
	doctor.minutes += 5
	_seconds(hud, 1)
	expect(hud.banner_text().contains("SHADE"), "his comeback arrives as a banner too")
	_seconds(hud, int(LobbyHud.BANNER_TIME) + 1)
	expect_equal(hud.banner_text(), "", "and fades")


func test_p_on_a_mac_a_swipe_up_and_esc() -> void:
	var events := InputMap.action_get_events(&"phone")
	expect(events.size() == 1 and events[0] is InputEventKey and (events[0] as InputEventKey).physical_keycode == KEY_P,
		"P is the phone key on a Mac")
	var doctor := _doctor(2, 9 * 60)
	var hud := _hud(doctor)
	hud._unhandled_input(_action(&"phone"))
	expect(hud.phone_open(), "P brings it up")
	hud._unhandled_input(_action(&"phone"))
	expect(not hud.phone_open(), "P again puts it away")
	hud.open_phone()
	hud._unhandled_input(_action(&"ui_cancel"))
	expect(not hud.phone_open() and not hud.menu_open(), "Esc puts the phone away")
	hud._unhandled_input(_action(&"ui_cancel"))
	expect(hud.menu_open(), "Esc with nothing open pauses")
	hud._unhandled_input(_action(&"phone"))
	expect(not hud.phone_open(), "no phone over the pause menu")
	hud._unhandled_input(_action(&"ui_cancel"))
	expect(not hud.menu_open(), "Esc again carries on")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(hud.size.x * 0.4, hud.size.y - UiKit.px(20))
	hud._input(down)
	var move := InputEventMouseMotion.new()
	move.position = down.position + Vector2(UiKit.px(4), -UiKit.px(60))
	hud._input(move)
	expect(hud.phone_open(), "a swipe up from the bottom brings it up")
	hud.close_phone()
	down.position = Vector2(hud.size.x * 0.4, hud.size.y * 0.5)
	hud._input(down)
	move.position = down.position + Vector2(0, -UiKit.px(80))
	hud._input(move)
	expect(not hud.phone_open(), "not a drag from the middle of the screen")
	down.position = Vector2(hud.size.x * 0.4, hud.size.y - UiKit.px(20))
	hud._input(down)
	move.position = down.position + Vector2(UiKit.px(90), -UiKit.px(45))
	hud._input(move)
	expect(not hud.phone_open(), "not a sideways drag")
	hud.set_talking(true)
	hud._unhandled_input(_action(&"phone"))
	hud._input(down)
	move.position = down.position + Vector2(0, -UiKit.px(60))
	hud._input(move)
	expect(not hud.phone_open(), "never while talking")


func test_a_tap_outside_the_phone_puts_it_away() -> void:
	var doctor := _doctor(1, 7 * 60 + 15)
	var hud := _hud(doctor)
	var phone := hud.open_phone()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	var down := up.duplicate() as InputEventMouseButton
	down.pressed = true
	phone._on_shade_input(up)
	expect(hud.phone_open(), "lifting the finger that swiped it up doesn't put it away")
	hud.ring(PhoneBook.call_due(doctor))
	phone._on_shade_input(down)
	phone._on_shade_input(up)
	expect(hud.phone_open() and phone.call_phase == "ringing", "nor while a call rings on it")
	hud.decline_ringing()
	phone._on_shade_input(down)
	phone._on_shade_input(up)
	expect(not hud.phone_open(), "a tap outside it does")


func test_lab_results_pages_the_feed_and_photos_show_on_the_phone() -> void:
	var doctor := _doctor(4, 12 * 60)
	var hud := _hud(doctor)
	hud.set_pager("Bed 3 needs you")
	hud.set_pager("Bed 3 needs you")
	hud.set_pager("Casualty: a red patient")
	expect_equal(hud.pager_log.size(), 2, "each page once")
	var sim := ShiftSim.new(5, 8 * 60)
	var patient := sim.make_patient("dka")
	sim.patients.append(patient)
	patient.ordered["sugar"] = 11 * 60
	patient.results["sugar"] = "Sugar 540"
	hud.live_lab = func() -> Array: return PhoneBook.casualty_lab(doctor, sim)
	var phone := hud.open_phone()
	var lab_icon := _button(phone, "App_lab")
	expect(lab_icon.find_child("Unread", true, false) != null, "new reports show on the Lab icon")
	phone.open_app("lab")
	expect(phone.find_child("Lab_d4_lakshmi", true, false) != null, "today's story report")
	expect(phone.find_child("Lab_cas_%d_sugar" % patient.id, true, false) != null, "and casualty's")
	phone.back()
	expect(_button(phone, "App_lab").find_child("Unread", true, false) == null, "read")
	phone.open_app("pager")
	var list := phone.find_child("List", true, false)
	expect(list.get_child(0).name == "Page_1" and list.get_child(1).name == "Page_0", "pages, newest first")
	phone.back()
	phone.open_app("feed")
	expect(phone.find_child("Post_d1_welcome", true, false) != null, "the hospital's welcome post")
	phone.back()
	phone.open_app("photos")
	expect(phone.find_child("Thumb_d1_gate", true, false) != null, "the doctor's own photo of the gate")
	expect(phone.find_child("Thumb_d1_dad", true, false) != null, "photos from chats are saved too")
	phone.open_photo("d1_gate")
	expect(phone.page == "photo" and phone.find_child("Big", true, false) != null, "a photo opens big")
	phone.back()
	expect_equal(phone.page, "photos")
	phone.back()
	phone.open_app("calls")
	expect(phone.find_child("Call_d1_mum_call", true, false) != null and phone.find_child("Call_d3_mum_busy", true, false) != null,
		"old missed calls in the log")


func test_no_page_is_wider_than_the_phone() -> void:
	var doctor := _doctor(12, 19 * 60)
	doctor.rank_held = 1
	var hud := _hud(doctor)
	var sim := ShiftSim.new(5, 8 * 60)
	var patient := sim.make_patient("renal_colic")
	sim.patients.append(patient)
	for test: String in ["urine", "usg"]:
		patient.ordered[test] = 11 * 60
		patient.results[test] = "A long result line that has to wrap inside the phone and never push it wider than it is."
	hud.live_lab = func() -> Array: return PhoneBook.casualty_lab(doctor, sim)
	hud.set_pager("A page long enough to need two lines inside the phone, about a patient in casualty.")
	var phone := hud.open_phone()
	var room := phone.body.size.x - UiKit.px(12) + 1.0
	var pages: Array = []
	for app: String in ["", "chats", "calls", "lab", "pager", "feed", "photos"]:
		pages.append([app, ""])
	for chat: String in ["family", "batch", "varun", "priya", "iyer"]:
		pages.append(["chat", chat])
	pages.append(["photo", "d1_gate"])
	for entry: Array in pages:
		phone._show(str(entry[0]), str(entry[1]), false)
		var page_width := (phone._holder.get_child(0) as Control).get_combined_minimum_size().x
		expect(page_width <= room, "%s %s fits: %.0f of %.0f" % [entry[0], entry[1], page_width, room])
	expect_equal(PhoneBook.initials("priya"), "P", "a name with a note in brackets")
	expect_equal(PhoneBook.initials("batch"), "CM", "the batch group")
	expect_equal(PhoneBook.initials("mum"), "M")
	expect_equal(PhoneBook.initials("varun"), "VK")
	expect_equal(PhoneBook.initials("iyer"), "I", "titles left out")


func test_the_battery_drains_over_a_shift() -> void:
	var doctor := _doctor(5, 7 * 60)
	var phone := PhonePanel.new(doctor)
	expect_equal(phone.battery(), 100, "full at the start of the day")
	doctor.minutes = 19 * 60
	expect(phone.battery() < 25, "low by the evening (%d%%)" % phone.battery())
	doctor.day = 6
	doctor.minutes = 20 * 60
	doctor.morning = {"day": 6, "minutes": 20 * 60}
	expect_equal(phone.battery(), 100, "a night shift starts charged")
	doctor.minutes = 40 * 60
	expect_equal(phone.battery(), 4, "and never quite dies")
	phone.free()


func test_empty_apps_say_so() -> void:
	var doctor := _doctor(1, 5 * 60)
	var hud := _hud(doctor)
	var phone := hud.open_phone()
	for app: String in ["chats", "calls", "lab", "pager", "feed", "photos"]:
		phone.open_app(app)
		expect(phone.find_child("Empty", true, false) != null, "%s says there's nothing yet" % app)
		phone.back()
	expect(phone.find_child("Recent", true, false) == null, "no latest messages before anyone has written")


func test_the_phone_fits_every_screen() -> void:
	for size: Vector2i in [Vector2i(1688, 780), Vector2i(1334, 750), Vector2i(2048, 1536), Vector2i(1280, 800)]:
		tree.root.size = size
		var hud := _hud(_doctor(2, 9 * 60))
		var phone := hud.open_phone()
		phone._layout()
		var screen := hud.get_viewport().get_visible_rect()
		var body := Rect2(phone.body.global_position, phone.body.size)
		expect(screen.encloses(body), "%s: the phone is on the screen" % size)
		expect(body.size.y >= UiKit.px(300), "%s: tall enough to read (%d)" % [size, body.size.y])
		expect(body.get_center().x > screen.size.x * 0.5, "%s: right of centre, so the tasks still show" % size)
		hud.get_parent().remove_child(hud)
		hud.free()
	tree.root.size = Vector2i(1688, 780)


# --- In the hospital --------------------------------------------------------------------------

func test_the_ward_clock_keeps_running_behind_the_phone() -> void:
	var ward := _ward(4)
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	var phone := ward.hud.open_phone()
	expect(phone != null, "the phone comes up on the ward")
	var at := ward.profile.minutes
	for frame in 300:
		ward.update(STEP)
	expect(ward.profile.minutes > at, "patients keep waiting while the doctor scrolls")
	expect(ward.hud.live_lab.is_valid(), "the ward hands casualty's results to the Lab app")
	ward.hud.set_talking(true)
	expect(not ward.hud.phone_open(), "a conversation puts the phone away")
	ward.hud.set_talking(false)
	ward._end_day()
	expect(ward.profile.phone["days"].has("4"), "the day is remembered for tonight's messages")


func test_the_phone_costs_little() -> void:
	var doctor := _doctor(20, 15 * 60)
	doctor.rank_held = 3
	var started := Time.get_ticks_usec()
	for round in 20:
		PhoneBook.forget()
		PhoneBook.items(doctor)
	var each := (Time.get_ticks_usec() - started) / 20.0 / 1000.0
	expect(each < 8.0, "everything on the phone worked out in %.2f ms" % each)
	started = Time.get_ticks_usec()
	for round in 20:
		PhoneBook.badge(doctor)
		PhoneBook.call_due(doctor)
	expect((Time.get_ticks_usec() - started) / 20.0 / 1000.0 < 2.0, "and looked at again almost free while nothing changes")
	var hud := _hud(doctor)
	started = Time.get_ticks_usec()
	var phone := hud.open_phone()
	phone.open_chat("family")
	phone.back()
	phone.open_app("photos")
	var build := (Time.get_ticks_usec() - started) / 1000.0
	expect(build < 120.0, "opening the phone, a chat and the photos took %.1f ms" % build)
