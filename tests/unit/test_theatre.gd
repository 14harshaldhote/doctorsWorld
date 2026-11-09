extends TestCase
## Day 3 in the hospital: the ward, consent, the scrub, Theatre 2 and the
## talk with Rohit's mother afterwards.

const CAREFUL := ["Ask Rohit", "Allergies", "Ask about the exam", "Explain", "Be straight", "Hold firm", "Honest", "Plain", "Own it"]
const HASTY := ["Explain", "Wait and see", "Soften", "Deflect", "Defend", "Doubt"]


func _theatre() -> Theatre:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 3
	doctor.opening_seen = true
	doctor.created = true
	return add_node(Theatre.new(doctor)) as Theatre


func test_the_day_starts_on_the_ward_with_dr_iyer() -> void:
	var theatre := _theatre()
	expect_equal(theatre.stage, "morning")
	expect(theatre.overlay.fade_amount() > 0.9, "a title card opens the day")
	for frame in 100:
		theatre.update(1.0 / 30.0)
	expect(theatre.story.is_playing(), "Dr. Iyer speaks first")
	expect_equal(theatre.conversation, "morning")
	theatre.talk_through()
	expect_equal(theatre.stage, "consent")
	expect_equal(theatre.mode, "walk")
	expect(theatre.hud.hint_text().contains("bed"), "the hint points to Rohit's bed")
	var bed := theatre.camera.unproject_position(theatre._tag_point("bed"))
	expect_equal(theatre.place_at(bed), "bed", "Rohit's bed can be tapped")


func test_consent_finds_the_allergy_and_the_hidden_pain_when_asked() -> void:
	var theatre := _theatre()
	theatre.skip_to("consent")
	theatre.go_to("bed")
	theatre.play_until(func() -> bool: return theatre.conversation == "consent")
	expect_equal(theatre.talking_with, "sunita", "the talk is with his mother")
	theatre.talk_through(Theatre.pick_tones(CAREFUL))
	var profile := theatre.profile
	for flag in ["rohit_pain_day", "rohit_allergy_known", "rohit_consent"]:
		expect(profile.has_flag(flag), flag)
	expect(not profile.has_flag("rohit_delayed"), "no waiting")
	expect_equal(theatre.stage, "scrub")
	expect(profile.trust("sunita", 35) > 35, "his mother trusts the doctor more")


func test_waiting_moves_the_operation_to_the_afternoon() -> void:
	var theatre := _theatre()
	theatre.skip_to("consent")
	theatre.go_to("bed")
	theatre.play_until(func() -> bool: return theatre.conversation == "consent")
	theatre.talk_through(Theatre.pick_tones(HASTY))
	expect(theatre.profile.has_flag("rohit_delayed"))
	expect(not theatre.profile.has_flag("rohit_allergy_known"), "nobody asked about allergies")
	expect(theatre.profile.minutes >= 13 * 60 + 50, "the clock jumps to the afternoon")


func test_scrubbing_leads_into_theatre_and_dr_khan() -> void:
	var theatre := _theatre()
	theatre.skip_to("scrub")
	expect(theatre.place_at(theatre.camera.unproject_position(theatre._tag_point("sink"))) == "sink")
	theatre.play_until(func() -> bool: return theatre.view != null)
	expect(theatre.view is ScrubView, "the scrub opens")
	expect_equal(theatre.view.trainer, "tom", "Tom coaches the scrub")
	theatre.play_until(func() -> bool: return theatre.view != null and theatre.view.result_open())
	expect(theatre.scrub_score >= 85, "the robot scrubs well")
	theatre.view.done_pressed.emit()
	expect_equal(theatre.stage, "theatre")
	expect_equal(theatre.conversation, "khan_intro", "Dr. Khan introduces herself")
	expect(theatre.rig_for("khan").joint("Head").has_node("Mask"), "the team wears masks")
	expect_equal(theatre.player.outfit, "theatre", "the doctor is gowned and gloved")
	expect_equal(theatre.rig_for("tom").outfit, "theatre", "so is the scrub nurse")
	expect_equal(theatre.rig_for("khan").outfit, "doctor", "the anaesthetist stays in her scrubs")
	theatre.talk_through(Theatre.pick_tones(["Honest"]))
	expect(theatre.view is OperationView, "then the operation")
	expect_equal(theatre.operation.setup["scrub"], theatre.scrub_score, "the scrub counts towards safety")


func _whole_day(quality: String, tones: Array) -> Theatre:
	var theatre := _theatre()
	var ended := [false]
	theatre.day_finished.connect(func() -> void: ended[0] = true)
	var bot := AutoPlayer.new()
	bot.quality = quality
	theatre.play_until(func() -> bool: return ended[0], Theatre.pick_tones(tones), bot, 900.0)
	expect(ended[0], "the day ends (%s)" % quality)
	return theatre


func test_a_careful_day_wins_and_his_mother_is_grateful() -> void:
	var xp_before := 0
	var theatre := _whole_day("good", CAREFUL)
	var profile := theatre.profile
	expect_equal(theatre.operation.outcome, "won")
	expect(profile.has_flag("op_rohit_won") and profile.has_flag("op_rohit_done"))
	expect(profile.total_xp > xp_before + 120, "an operation earns a lot of XP")
	expect(profile.best_score("appendix") >= 75, "the score is kept")
	expect(profile.trust("sunita", 35) >= 50, "his mother trusts the doctor")
	expect(theatre.story.runner.history.any(func(line: Array) -> bool: return str(line[1]).begins_with("Thank God")),
		"she thanks the doctor")
	expect_equal(theatre.stage, "end")
	expect_equal(theatre.player.outfit, "doctor", "out of the gown for the ward")
	expect(not theatre.player.joint("Head").has_node("Mask"), "and the mask is off")


func test_a_hasty_shaky_day_is_a_struggle() -> void:
	var theatre := _whole_day("shaky", HASTY)
	expect_equal(theatre.operation.outcome, "struggled")
	expect("burst" in theatre.operation.happened, "waiting let it burst")
	expect(theatre.profile.has_flag("op_burst"), "the story knows it burst")
	expect(theatre.story.runner.history.any(func(line: Array) -> bool: return str(line[1]).begins_with("You got there")),
		"Dr. Iyer's debrief says so")


func test_a_bad_day_ends_in_intensive_care() -> void:
	var theatre := _whole_day("bad", HASTY)
	expect_equal(theatre.operation.outcome, "failed")
	expect(theatre.operation.takeover)
	expect(theatre.profile.has_flag("op_rohit_failed"))
	expect(theatre.profile.trust("iyer", 50) < 60, "Dr. Iyer's trust doesn't grow")
	expect(theatre.story.runner.history.any(func(line: Array) -> bool: return str(line[1]).contains("intensive care")),
		"his mother hears he's in intensive care")
