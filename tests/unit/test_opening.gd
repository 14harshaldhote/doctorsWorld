extends TestCase
## The opening story: convocation, the letter at home and the first morning.


func _opening(profile: PlayerProfile = null) -> Opening:
	var player := profile
	if player == null:
		player = PlayerProfile.new()
		player.name = "Kiran Rao"
		player.address_form = "first"
	var opening := Opening.new(player)
	add_node(opening)
	return opening


func _said(opening: Opening, speaker: String) -> Array[String]:
	var lines: Array[String] = []
	for line: Array in opening.story.runner.history:
		if line[0] == speaker:
			lines.append(str(line[1]))
	return lines


func test_it_starts_at_convocation_with_a_title_card() -> void:
	var opening := _opening()
	expect_equal(opening.set_name, "graduation")
	expect(opening.current_set is GraduationHall)
	opening.update(0.6)
	expect(opening.overlay._card.modulate.a > 0.5, "the title card shows")
	expect_equal(opening.overlay._card_title.text, "Convocation day")
	var player: AvatarRig = opening.current_set.actors["you"]
	expect_equal(player.outfit, "gown", "the player graduates in a gown")
	expect(player.joint("Mortarboard") != null, "and the cap")


func test_the_dean_calls_out_the_players_name() -> void:
	var opening := _opening()
	var reached := opening.play_until(func() -> bool: return _said(opening, "dean").has("Kiran Rao!"))
	expect(reached, "the dean reads out the name")
	reached = opening.play_until(func() -> bool:
		return (opening.current_set.actors["you"] as AvatarRig).held() == "certificate")
	expect(reached, "the certificate is handed over")
	expect(opening.mark("dean_front") != null, "the stage has its marks")


func test_the_family_cheers_with_their_own_lines() -> void:
	var opening := _opening()
	opening.play_until(func() -> bool: return not _said(opening, "anu").is_empty())
	expect(_said(opening, "anu")[0].contains("Kiran"), "Anu shouts the first name")
	var anu: AvatarRig = opening.current_set.actors["anu"]
	expect_equal(anu.gesture, "cheer", "Anu is cheering")
	expect(anu.talking, "and her mouth moves")
	var dad: AvatarRig = opening.current_set.actors["dad"]
	expect(dad.listening or dad.gesture == "clap", "Dad is part of the moment")
	opening.play_until(func() -> bool: return not _said(opening, "mum").is_empty())
	expect_equal(_said(opening, "dad").size(), 1, "Dad gets his line in before Mum")


func test_the_letter_arrives_at_home_and_folds_away() -> void:
	var opening := _opening()
	var reached := opening.play_until(func() -> bool: return opening.overlay.letter_open(), -1)
	expect(reached, "the letter opens")
	expect_equal(opening.set_name, "home")
	opening._on_tap()
	expect(not opening.overlay.letter_open(), "a tap folds the letter")
	var unopened := _opening()
	unopened.play_until(func() -> bool: return unopened.overlay.letter_open(), -1)
	for frame in int((StoryOverlay.LETTER_TIME + 0.5) * 30):
		unopened.update(1.0 / 30.0)
	expect(not unopened.overlay.letter_open(), "the letter folds itself if nobody taps")


func test_the_familys_question_changes_their_trust() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	var opening := _opening(profile)
	var reached := opening.play_until(func() -> bool: return opening.ui.is_choosing(), -1)
	expect(reached, "Mum's question waits for a reply")
	expect_equal(opening.ui.choice_buttons().size(), 3)
	opening.story.choose(2)
	expect(profile.has_flag("admitted_fear"), "the honest answer is remembered")
	expect_equal(profile.trust("family", 60), 66)


func test_the_morning_ends_at_the_hospital_doors() -> void:
	var opening := _opening()
	var ended := [false, false]
	opening.finished.connect(func(skipped: bool) -> void:
		ended[0] = true
		ended[1] = skipped)
	var reached := opening.play_until(func() -> bool: return opening.set_name == "morning")
	expect(reached, "the first morning comes")
	var street := opening.current_set as MorningStreet
	expect(street != null)
	reached = opening.play_until(func() -> bool: return street.front.is_driving())
	expect(reached, "an ambulance comes down the road")
	reached = opening.play_until(func() -> bool: return opening.ui.line_text().begins_with("Okay"))
	expect(not street.front.is_driving(), "and has pulled up before the doctor looks up at the sign")
	expect(street.front.ambulance.position.x > 4.0, "by the entrance")
	reached = opening.play_until(func() -> bool: return opening.is_done())
	expect(reached, "the opening finishes by itself")
	expect(ended[0] and not ended[1], "finished, not skipped")
	var player: AvatarRig = opening.current_set.actors["you"]
	expect(player.global_position.distance_to(opening.mark("doors") as Vector3) < 0.2, "at the doors")
	expect_equal(player.outfit, "doctor", "dressed for the first day")


func test_holding_skips_the_whole_thing() -> void:
	var opening := _opening()
	var skipped := [false]
	opening.finished.connect(func(was_skipped: bool) -> void: skipped[0] = was_skipped)
	opening.update(1.0)
	opening.ui._pressing = true
	for frame in 40:
		opening.update(1.0 / 30.0)
	expect(opening.is_done(), "holding for a second skips")
	expect(skipped[0], "and says it was skipped")


func test_a_short_tap_moves_the_subtitles_on_but_does_not_skip() -> void:
	var opening := _opening()
	opening.play_until(func() -> bool: return opening.ui.is_typing())
	var line := opening.ui.line_text()
	opening.ui.tap()
	expect(not opening.ui.is_typing(), "a tap finishes the line")
	opening.ui.tap()
	opening.update(0.05)
	expect(opening.ui.line_text() != line or not opening.story.is_busy(), "a second tap moves on")
	expect(not opening.is_done(), "taps never skip the story")
